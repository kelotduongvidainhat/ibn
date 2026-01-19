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
	"github.com/ibn/backend/internal/ipfs"
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



	// 4. Initialize API Server
	r := gin.Default()

	// 5. Middleware (CORS)
	r.Use(cors.Default())

	// 6. Routes
	ipfsClient := ipfs.NewClient()
	assetHandler := &handlers.AssetHandler{Gateway: gateway, IPFS: ipfsClient}
	adminHandler := handlers.NewAdminHandler()

	api := r.Group("/api")
	{
		// Parameterized routes (New)
		api.GET("/:channel/:ccname/assets", assetHandler.GetAllAssets)
		api.GET("/:channel/:ccname/assets/query", assetHandler.QueryAssets)
		api.POST("/:channel/:ccname/assets", assetHandler.CreateAsset)
		api.GET("/:channel/:ccname/assets/:id", assetHandler.ReadAsset)
		api.GET("/:channel/:ccname/bridge/:targetChannel/:id", assetHandler.ReadAssetFromBridge)

		// Legacy routes (Fallback to env defaults)
		api.GET("/assets", assetHandler.GetAllAssets)
		api.GET("/assets/query", assetHandler.QueryAssets)
		api.POST("/assets", assetHandler.CreateAsset)
		api.GET("/assets/:id", assetHandler.ReadAsset)
	}

	admin := r.Group("/api/admin")
	{
		admin.GET("/health", adminHandler.RunHealthCheck)
		admin.GET("/resources", adminHandler.GetResourceUsage)
		admin.POST("/approve", adminHandler.MassApprove)
		admin.POST("/commit", adminHandler.MassCommit)
		admin.POST("/channels", adminHandler.CreateChannel)
		admin.POST("/upgrade", adminHandler.UpgradeChaincode)
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
