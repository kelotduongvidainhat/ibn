package main // Defines the package name for the entry point

import (
	"log" // Standard logging package
	"os"  // Package to access environment variables

	"github.com/hyperledger/fabric-chaincode-go/shim"               // Fabric Shim for chaincode server
	"github.com/hyperledger/fabric-contract-api-go/contractapi" // Fabric Contract API
	"github.com/joho/godotenv"                                  // Load .env file
)

func main() {
	// Load environment variables from .env file if it exists
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file found, relying on system environment variables")
	}

	// 1. Initialize our SmartContract logic
	assetChaincode, err := contractapi.NewChaincode(&SmartContract{})
	if err != nil {
		log.Panicf("Error creating asset-transfer-basic chaincode: %v", err) // Panic if initialization fails
	}

	// 2. Read Configuration for CaaS
	serverAddr := os.Getenv("CHAINCODE_SERVER_ADDRESS") // Address where this CC will listen (e.g. 0.0.0.0:9999)
	ccid := os.Getenv("CHAINCODE_ID")                   // Package ID received during install (or placeholder)

	// 3. Start the Chaincode as a Service (external server)
	server := &shim.ChaincodeServer{
		CCID:    ccid,       // Identify which CC this server provides
		Address: serverAddr, // Network address to listen on
		CC:      assetChaincode, // The logic defined in smartcontract.go
		TLSProps: shim.TLSProperties{
			Disabled: true, // TLS is disabled for this internal hop in the MVP (optional to enable later)
		},
	}

	// 4. Run the server
	log.Printf("Starting chaincode server on %s", serverAddr)
	if err := server.Start(); err != nil {
		log.Panicf("Error starting asset-transfer-basic chaincode: %v", err) // Log and panic on failure
	}
}
