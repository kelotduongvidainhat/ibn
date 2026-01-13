package main // Defines the package name

import (
	"encoding/json" // Used for marshaling/unmarshaling JSON data
	"fmt"           // Used for formatted I/O operations

	"github.com/hyperledger/fabric-chaincode-go/shim"
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
// InitLedger adds a base set of assets to the ledger
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	assets := []Asset{
		{ID: "asset1", Color: "blue", Size: 5, Owner: "Tomoko", AppraisedValue: 300},
		{ID: "asset2", Color: "red", Size: 5, Owner: "Brad", AppraisedValue: 400},
		{ID: "asset3", Color: "green", Size: 10, Owner: "Jin Soo", AppraisedValue: 500},
		{ID: "asset4", Color: "yellow", Size: 10, Owner: "Max", AppraisedValue: 600},
		{ID: "asset5", Color: "black", Size: 15, Owner: "Adriana", AppraisedValue: 700},
		{ID: "asset6", Color: "white", Size: 15, Owner: "Michel", AppraisedValue: 800},
	}

	for _, asset := range assets {
		assetJSON, err := json.Marshal(asset)
		if err != nil {
			return err
		}

		err = ctx.GetStub().PutState(asset.ID, assetJSON)
		if err != nil {
			return fmt.Errorf("failed to put to world state. %v", err)
		}
	}

	return nil
}

// CreateAsset issues a new asset to the world state
func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id string, color string, size int, owner string, appraisedValue int) error {
	fmt.Printf("DEBUG: CreateAsset called for ID: %s, Color: %s, Size: %d, Owner: %s, Value: %d\n", id, color, size, owner, appraisedValue)
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
	fmt.Printf("DEBUG: Putting state for %s\n", id)
	return ctx.GetStub().PutState(id, assetJSON)
}

// ReadAsset returns the asset stored in the world state with given id
func (s *SmartContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	fmt.Printf("DEBUG: ReadAsset called for ID: %s\n", id)
	// Retrieve the asset from the ledger
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if assetJSON == nil {
		fmt.Printf("DEBUG: Asset %s not found\n", id)
		return nil, fmt.Errorf("the asset %s does not exist", id) // Error if not found
	}

	// Unmarshal JSON bytes into Asset struct
	var asset Asset
	err = json.Unmarshal(assetJSON, &asset)
	if err != nil {
		return nil, err // Return if unmarshaling fails
	}

	fmt.Printf("DEBUG: Asset found: %+v\n", asset)
	return &asset, nil // Return the asset object
}

// AssetExists returns true when asset with given ID exists in world state
func (s *SmartContract) AssetExists(ctx contractapi.TransactionContextInterface, id string) (bool, error) {
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return false, fmt.Errorf("failed to read from world state: %v", err)
	}

	return assetJSON != nil, nil
}

// QueryAssets executes a rich query string against the state database (CouchDB)
func (s *SmartContract) QueryAssets(ctx contractapi.TransactionContextInterface, queryString string) ([]*Asset, error) {
	fmt.Printf("DEBUG: QueryAssets called with query: %s\n", queryString)
	resultsIterator, err := ctx.GetStub().GetQueryResult(queryString)
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	return constructQueryResponseFromIterator(resultsIterator)
}

// GetAssetsByColor demonstrates a specialized high-level query
func (s *SmartContract) GetAssetsByColor(ctx contractapi.TransactionContextInterface, color string) ([]*Asset, error) {
	queryString := fmt.Sprintf(`{"selector":{"Color":"%s"}}`, color)
	return s.QueryAssets(ctx, queryString)
}

// GetAllAssets returns all assets found in world state
func (s *SmartContract) GetAllAssets(ctx contractapi.TransactionContextInterface) ([]*Asset, error) {
	resultsIterator, err := ctx.GetStub().GetStateByRange("", "")
	if err != nil {
		return nil, err
	}
	defer resultsIterator.Close()

	return constructQueryResponseFromIterator(resultsIterator)
}

// constructQueryResponseFromIterator is a helper to parse iterator results into an Asset slice
func constructQueryResponseFromIterator(resultsIterator shim.StateQueryIteratorInterface) ([]*Asset, error) {
	var assets []*Asset
	for resultsIterator.HasNext() {
		queryResponse, err := resultsIterator.Next()
		if err != nil {
			return nil, err
		}

		var asset Asset
		err = json.Unmarshal(queryResponse.Value, &asset)
		if err != nil {
			return nil, err
		}
		assets = append(assets, &asset)
	}

	return assets, nil
}
