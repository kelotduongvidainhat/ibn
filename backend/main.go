package main

import (
	"log"
	"os"
	"time"

	"github.com/gin-contrib/cors"
	"github.com/gin-gonic/gin"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/ibn/backend/internal/fabric"
	"github.com/ibn/backend/internal/handlers"
	"github.com/joho/godotenv"
)

func main() {
	// 1. Load Environment
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, relying on system env")
	}

	// 2. Initialize Fabric Gateway
	clientConnection, err := fabric.NewGrpcConnection()
	if err != nil {
		log.Fatalf("Failed to create gRPC connection: %v", err)
	}
	defer clientConnection.Close()

	id, err := fabric.NewIdentity()
	if err != nil {
		log.Fatalf("Failed to create identity: %v", err)
	}

	sign, err := fabric.NewSign()
	if err != nil {
		log.Fatalf("Failed to create sign: %v", err)
	}

	gateway, err := client.Connect(
		id,
		client.WithSign(sign),
		client.WithClientConnection(clientConnection),
		client.WithEvaluateTimeout(5*time.Second),
		client.WithEndorseTimeout(15*time.Second),
		client.WithSubmitTimeout(5*time.Second),
		client.WithCommitStatusTimeout(1*time.Minute),
	)
	if err != nil {
		log.Fatalf("Failed to connect to gateway: %v", err)
	}
	defer gateway.Close()

	// 3. Setup Network Objects
	network := gateway.GetNetwork(os.Getenv("CHANNEL_NAME"))
	contract := network.GetContract(os.Getenv("CHAINCODE_NAME"))

	// 4. Initialize API Server
	r := gin.Default()

	// 5. Middleware (CORS)
	r.Use(cors.Default())

	// 6. Routes
	assetHandler := &handlers.AssetHandler{Contract: contract}
	adminHandler := handlers.NewAdminHandler()

	api := r.Group("/api")
	{
		api.POST("/assets", assetHandler.CreateAsset)
		api.GET("/assets/:id", assetHandler.ReadAsset)
	}

	admin := r.Group("/api/admin")
	{
		admin.GET("/health", adminHandler.RunHealthCheck)
		admin.GET("/resources", adminHandler.GetResourceUsage)
		admin.POST("/approve", adminHandler.MassApprove)
		admin.POST("/commit", adminHandler.MassCommit)
	}

	// 7. Start Server
	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}

	log.Printf("Backend API server starting on :%s", port)
	if err := r.Run(":" + port); err != nil {
		log.Fatalf("Failed to run server: %v", err)
	}
}
