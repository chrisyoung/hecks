package main

import (
	"fmt"
	"os"
	"strconv"
	"compliance_domain/server"
)

func main() {
	port := 9292
	if p := os.Getenv("PORT"); p != "" {
		if v, err := strconv.Atoi(p); err == nil { port = v }
	}
	if len(os.Args) > 1 {
		if v, err := strconv.Atoi(os.Args[1]); err == nil { port = v }
	}
	app := server.NewApp()
	if err := app.Start(port); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
