package main // Defines the package name

import (
	"encoding/json" // Used for marshaling/unmarshaling JSON data
	"fmt"           // Used for formatted I/O operations

	"github.com/hyperledger/fabric-contract-api-go/contractapi" // Main Fabric Contract API
)

// SmartContract defines the base structure for the smart contract
type SmartContract struct {
	contractapi.Contract // Embeds the contractapi.Contract for base functionality
}

// Asset describes the basic properties of a digital asset
type Asset struct {
	ID             string `json:"ID"`             // Unique identifier for the asset
	Color          string `json:"Color"`          // Asset color property
	Size           int    `json:"Size"`           // Asset size property
	Owner          string `json:"Owner"`          // Current owner of the asset
	AppraisedValue int    `json:"AppraisedValue"` // Market value of the asset
}

// CreateAsset issues a new asset to the world state
func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id string, color string, size int, owner string, appraisedValue int) error {
	// Check if asset already exists
	exists, err := s.AssetExists(ctx, id)
	if err != nil {
		return err // Return if system error occurs
	}
	if exists {
		return fmt.Errorf("the asset %s already exists", id) // Return error if ID is taken
	}

	// Create the asset object
	asset := Asset{
		ID:             id,
		Color:          color,
		Size:           size,
		Owner:          owner,
		AppraisedValue: appraisedValue,
	}
	
	// Convert asset to JSON bytes
	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err // Return if marshaling fails
	}

	// Put the asset on the ledger (key-value pair)
	return ctx.GetStub().PutState(id, assetJSON)
}

// ReadAsset returns the asset stored in the world state with given id
func (s *SmartContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	// Retrieve the asset from the ledger
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if assetJSON == nil {
		return nil, fmt.Errorf("the asset %s does not exist", id) // Error if not found
	}

	// Unmarshal JSON bytes into Asset struct
	var asset Asset
	err = json.Unmarshal(assetJSON, &asset)
	if err != nil {
		return nil, err // Return if unmarshaling fails
	}

	return &asset, nil // Return the asset object
}

// AssetExists returns true when asset with given ID exists in world state
func (s *SmartContract) AssetExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	// Get State returns nil if no value is found under the key
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}

	return assetJSON != nil, nil // Return true if data was found
}
