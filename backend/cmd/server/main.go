package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	firebase "firebase.google.com/go/v4"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"google.golang.org/api/option"

	"github.com/apptest-messaging/backend/internal/config"
	"github.com/apptest-messaging/backend/internal/handlers"
	"github.com/apptest-messaging/backend/internal/middleware"
	appredis "github.com/apptest-messaging/backend/internal/redis"
	"github.com/apptest-messaging/backend/internal/repositories"
	"github.com/apptest-messaging/backend/internal/services"
)

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

	pool, err := pgxpool.New(ctx, cfg.DatabaseURL)
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

	gin.SetMode(gin.ReleaseMode)
	if os.Getenv("GIN_MODE") == "debug" {
		gin.SetMode(gin.DebugMode)
	}

	r := gin.New()
	r.Use(gin.Recovery())
	r.Use(middleware.CORSAllowlist(cfg.CORSAllowedOrigins))

	r.GET("/healthz", handlers.Health)
	r.GET("/readyz", handlers.Ready(handlers.ReadyDeps{Pool: pool, Redis: rdb}))

	api := r.Group("/api/v1")
	api.Use(middleware.FirebaseAuth(authClient))
	api.GET("/me", handlers.Me(meSvc))

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
