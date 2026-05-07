package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"regexp"
	"syscall"
	"time"

	firebase "firebase.google.com/go/v4"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/api/option"

	"github.com/apptest-messaging/backend/internal/config"
	"github.com/apptest-messaging/backend/internal/handlers"
	"github.com/apptest-messaging/backend/internal/middleware"
	appredis "github.com/apptest-messaging/backend/internal/redis"
	"github.com/apptest-messaging/backend/internal/repositories"
	"github.com/apptest-messaging/backend/internal/services"
	appws "github.com/apptest-messaging/backend/internal/ws"
)

var validDatabaseSchema = regexp.MustCompile(`^[a-zA-Z_][a-zA-Z0-9_]*$`)

func main() {
	if err := run(); err != nil {
		log.Fatalf("server: %v", err)
	}
}

func run() error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	ctx := context.Background()

	pool, err := newPGPool(ctx, cfg.DatabaseURL, cfg.DatabaseSchema)
	if err != nil {
		return fmt.Errorf("postgres: %w", err)
	}
	defer pool.Close()

	rdb, err := appredis.New(cfg.RedisURL)
	if err != nil {
		return fmt.Errorf("redis: %w", err)
	}
	defer rdb.Close()

	fbApp, err := firebase.NewApp(ctx, nil, option.WithCredentialsFile(cfg.GoogleApplicationCredentialsPath))
	if err != nil {
		return fmt.Errorf("firebase app: %w", err)
	}
	authClient, err := fbApp.Auth(ctx)
	if err != nil {
		return fmt.Errorf("firebase auth: %w", err)
	}

	userRepo := repositories.NewUserRepository(pool)
	meSvc := services.NewMeService(userRepo, rdb)
	convRepo := repositories.NewConversationRepository(pool)
	msgRepo := repositories.NewMessageRepository(pool)
	chatSvc := services.NewChatService(userRepo, convRepo, msgRepo)

	gin.SetMode(gin.ReleaseMode)
	if os.Getenv("GIN_MODE") == "debug" {
		gin.SetMode(gin.DebugMode)
	}

	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.CORSAllowlist(cfg.CORSAllowedOrigins))

	r.GET("/healthz", handlers.Health)
	r.GET("/readyz", handlers.Ready(handlers.ReadyDeps{Pool: pool, Redis: rdb}))

	wsHub := appws.NewHub()
	r.GET("/ws", appws.Handler(appws.HandlerDeps{
		Firebase:       authClient,
		Me:             meSvc,
		Hub:            wsHub,
		Convs:          convRepo,
		Msgs:           msgRepo,
		AllowedOrigins: cfg.CORSAllowedOrigins,
	}))

	v1Pub := r.Group("/api/v1")
	v1Pub.POST("/auth/anonymous", handlers.AnonymousDemoSignIn(userRepo, authClient))

	api := r.Group("/api/v1")
	api.Use(middleware.FirebaseAuth(authClient))
	api.GET("/me", handlers.Me(meSvc))
	api.GET("/users/search", handlers.UsersSearch(chatSvc, meSvc))
	api.POST("/conversations/direct", handlers.ConversationsDirect(chatSvc, meSvc))
	api.GET("/inbox", handlers.Inbox(chatSvc, meSvc))
	api.GET("/conversations/:conversationId/messages", handlers.ConversationMessages(chatSvc, meSvc))
	api.POST("/conversations/:conversationId/read", handlers.ConversationRead(chatSvc, meSvc))
	api.POST("/conversations/:conversationId/hide", handlers.ConversationHide(chatSvc, meSvc))

	addr := ":" + cfg.Port
	srv := &http.Server{
		Addr:              addr,
		Handler:           r,
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       30 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       120 * time.Second,
	}

	go func() {
		log.Printf("listening on %s", addr)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("listen: %v", err)
		}
	}()

	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	return srv.Shutdown(shutdownCtx)
}

func newPGPool(ctx context.Context, databaseURL, schema string) (*pgxpool.Pool, error) {
	pc, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		return nil, fmt.Errorf("parse config: %w", err)
	}
	if schema != "" {
		if !validDatabaseSchema.MatchString(schema) {
			return nil, fmt.Errorf("DATABASE_SCHEMA must match ^[a-zA-Z_][a-zA-Z0-9_]*$")
		}
		pc.AfterConnect = func(ctx context.Context, conn *pgx.Conn) error {
			q := "SET search_path TO " + pgx.Identifier{schema}.Sanitize()
			_, err := conn.Exec(ctx, q)
			return err
		}
	}
	return pgxpool.NewWithConfig(ctx, pc)
}
