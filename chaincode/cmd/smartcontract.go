package main // Defines the package name

import (
	"encoding/json" // Used for marshaling/unmarshaling JSON data
	"fmt"           // Used for formatted I/O operations

	"github.com/hyperledger/fabric-chaincode-go/shim"
	"github.com/hyperledger/fabric-contract-api-go/contractapi" // Main Fabric Contract API
)

// hasRole is a helper to verify if the client has a specific role attribute
func (s *SmartContract) hasRole(ctx contractapi.TransactionContextInterface, role string) (bool, error) {
	val, ok, err := ctx.GetClientIdentity().GetAttributeValue("role")
	if err != nil {
		return false, fmt.Errorf("failed to get attribute value: %v", err)
	}
	if !ok {
		return false, nil
	}
	return val == role, nil
}

// SmartContract defines the base structure for the smart contract
type SmartContract struct {
	contractapi.Contract // Embeds the contractapi.Contract for base functionality
}

// Asset describes the basic properties of a digital asset
type Asset struct {
	ID                     string `json:"ID"`                     // Unique identifier for the asset
	Color                  string `json:"Color"`                  // Asset color property
	Size                   int    `json:"Size"`                   // Asset size property
	Owner                  string `json:"Owner"`                  // Current owner of the asset
	AppraisedValue         int    `json:"AppraisedValue"`         // Market value of the asset (Private)
	IsPrivateDataAvailable bool   `json:"IsPrivateDataAvailable"` // Flag indicating if private data was retrieved
	FileCID                string `json:"FileCID"`                // IPFS Content Identifier
	FileName               string `json:"FileName"`               // Original name of the uploaded file
}

const collectionName = "assetCollection"

// InitLedger adds a base set of assets to the ledger
func (s *SmartContract) InitLedger(ctx contractapi.TransactionContextInterface) error {
	isAdmin, _ := s.hasRole(ctx, "admin")
	if !isAdmin {
		return fmt.Errorf("access denied: only users with role 'admin' can initialize the ledger")
	}

	assets := []Asset{
		{ID: "asset1", Color: "blue", Size: 5, Owner: "Tomoko", AppraisedValue: 300},
		{ID: "asset2", Color: "red", Size: 5, Owner: "Brad", AppraisedValue: 400},
		{ID: "asset3", Color: "green", Size: 10, Owner: "Jin Soo", AppraisedValue: 500},
		{ID: "asset4", Color: "yellow", Size: 10, Owner: "Max", AppraisedValue: 600},
		{ID: "asset5", Color: "black", Size: 15, Owner: "Adriana", AppraisedValue: 700},
		{ID: "asset6", Color: "white", Size: 15, Owner: "Michel", AppraisedValue: 800},
	}

	for _, asset := range assets {
		// Public data
		assetPublic := Asset{
			ID:       asset.ID,
			Color:    asset.Color,
			Size:     asset.Size,
			Owner:    asset.Owner,
			FileCID:  "",
			FileName: "",
		}
		assetJSON, err := json.Marshal(assetPublic)
		if err != nil {
			return err
		}

		err = ctx.GetStub().PutState(asset.ID, assetJSON)
		if err != nil {
			return fmt.Errorf("failed to put to world state. %v", err)
		}

		// Private data
		err = ctx.GetStub().PutPrivateData(collectionName, asset.ID, []byte(fmt.Sprintf("%d", asset.AppraisedValue)))
		if err != nil {
			return fmt.Errorf("failed to put to private collection. %v", err)
		}
	}

	return nil
}

// CreateAsset issues a new asset to the world state
func (s *SmartContract) CreateAsset(ctx contractapi.TransactionContextInterface, id string, color string, size int, owner string, fileCID string, fileName string) error {
	isAdmin, _ := s.hasRole(ctx, "admin")
	isManager, _ := s.hasRole(ctx, "manager")
	if !isAdmin && !isManager {
		return fmt.Errorf("access denied: only users with role 'admin' or 'manager' can create assets")
	}

	fmt.Printf("DEBUG: CreateAsset called for ID: %s, Color: %s, Size: %d, Owner: %s\n", id, color, size, owner)
	
	// Check if asset already exists
	exists, err := s.AssetExists(ctx, id)
	if err != nil {
		return err
	}
	if exists {
		return fmt.Errorf("the asset %s already exists", id)
	}

	// Get private data from transient map
	transientMap, err := ctx.GetStub().GetTransient()
	if err != nil {
		return fmt.Errorf("error getting transient: %v", err)
	}

	appraisedValueJSON, ok := transientMap["appraisedValue"]
	if !ok {
		return fmt.Errorf("appraisedValue must be provided in transient map")
	}

	// Create the asset object for public storage
	asset := Asset{
		ID:       id,
		Color:    color,
		Size:     size,
		Owner:    owner,
		FileCID:  fileCID,
		FileName: fileName,
	}
	
	assetJSON, err := json.Marshal(asset)
	if err != nil {
		return err
	}

	// Put the asset on the public ledger
	err = ctx.GetStub().PutState(id, assetJSON)
	if err != nil {
		return err
	}

	// Put the private data
	return ctx.GetStub().PutPrivateData(collectionName, id, appraisedValueJSON)
}

// ReadAsset returns the asset stored in the world state with given id
func (s *SmartContract) ReadAsset(ctx contractapi.TransactionContextInterface, id string) (*Asset, error) {
	fmt.Printf("DEBUG: ReadAsset called for ID: %s\n", id)
	
	// Retrieve the public asset from the ledger
	assetJSON, err := ctx.GetStub().GetState(id)
	if err != nil {
		return nil, fmt.Errorf("failed to read from world state: %v", err)
	}
	if assetJSON == nil {
		return nil, fmt.Errorf("the asset %s does not exist", id)
	}

	var asset Asset
	err = json.Unmarshal(assetJSON, &asset)
	if err != nil {
		return nil, err
	}

	// Try to retrieve private data
	privateData, err := ctx.GetStub().GetPrivateData(collectionName, id)
	if err == nil && privateData != nil {
		var appraisedValue int
		_, err = fmt.Sscanf(string(privateData), "%d", &appraisedValue)
		if err == nil {
			asset.AppraisedValue = appraisedValue
			asset.IsPrivateDataAvailable = true
		}
	}

	return &asset, nil
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

	return s.constructQueryResponseFromIterator(ctx, resultsIterator)
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

	return s.constructQueryResponseFromIterator(ctx, resultsIterator)
}

// ReadAssetFromChannel performs a cross-channel query to retrieve an asset from a target channel
func (s *SmartContract) ReadAssetFromChannel(ctx contractapi.TransactionContextInterface, targetChannel string, assetID string) (*Asset, error) {
	// Prepare arguments for the cross-channel call
	args := [][]byte{[]byte("ReadAsset"), []byte(assetID)}

	// Direct cross-channel call (Read-only)
	// We assume the chaincode name is also "basic" on the target channel
	response := ctx.GetStub().InvokeChaincode("basic", args, targetChannel)

	if response.Status != 200 {
		return nil, fmt.Errorf("failed to query channel %s: %s", targetChannel, response.Message)
	}

	var asset Asset
	if err := json.Unmarshal(response.Payload, &asset); err != nil {
		return nil, fmt.Errorf("failed to unmarshal cross-channel response: %v", err)
	}

	return &asset, nil
}

// constructQueryResponseFromIterator is a helper to parse iterator results into an Asset slice
func (s *SmartContract) constructQueryResponseFromIterator(ctx contractapi.TransactionContextInterface, resultsIterator shim.StateQueryIteratorInterface) ([]*Asset, error) {
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

		// Try to enrich with private data
		privateData, err := ctx.GetStub().GetPrivateData(collectionName, asset.ID)
		if err == nil && privateData != nil {
			var appraisedValue int
			_, err = fmt.Sscanf(string(privateData), "%d", &appraisedValue)
			if err == nil {
				asset.AppraisedValue = appraisedValue
				asset.IsPrivateDataAvailable = true
			}
		}

		assets = append(assets, &asset)
	}

	return assets, nil
}