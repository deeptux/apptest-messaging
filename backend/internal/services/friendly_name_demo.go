package services

import (
	"crypto/rand"
	"fmt"
	"math/big"
)

// Positive adjectives and nouns for demo-friendly random display handles.
var friendlyAdjectives = []string{
	"Brave", "Bright", "Calm", "Clever", "Creative", "Curious",
	"Daring", "Eager", "Friendly", "Generous", "Gentle", "Happy",
	"Hopeful", "Joyful", "Kind", "Lively", "Noble", "Patient",
	"Polite", "Proud", "Quick", "Radiant", "Serene", "Sincere",
	"Thoughtful", "Trusty", "Vibrant", "Warm", "Wise", "Wonderful",
}

var friendlyNouns = []string{
	"River", "Meadow", "Harbor", "Summit", "Orchard", "Canyon",
	"Lagoon", "Glacier", "Horizon", "Beacon", "Cottage", "Voyage",
	"Lantern", "Compass", "Anchor", "Breeze", "Coral", "Dolphin",
	"Echo", "Falcon", "Grove", "Heather", "Island", "Journey",
	"Knight", "Lighthouse", "Mirror", "Nebula", "Olive", "Pebble",
}

// RandomFriendlyPhrase returns "{Adjective} {Noun}" for demo display names.
func RandomFriendlyPhrase() string {
	a := friendlyAdjectives[cryptoRandInt(len(friendlyAdjectives))]
	n := friendlyNouns[cryptoRandInt(len(friendlyNouns))]
	return fmt.Sprintf("%s %s", a, n)
}

func cryptoRandInt(mod int) int {
	if mod <= 0 {
		return 0
	}
	x, err := rand.Int(rand.Reader, big.NewInt(int64(mod)))
	if err != nil {
		return 0
	}
	return int(x.Int64())
}
