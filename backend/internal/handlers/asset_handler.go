package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"

	"github.com/gin-gonic/gin"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/ibn/backend/internal/ipfs"
	"github.com/ibn/backend/internal/models"
)

type AssetHandler struct {
	Gateway *client.Gateway
	IPFS    *ipfs.Client
}

// getContract dynamically resolves the contract based on URL parameters
func (h *AssetHandler) getContract(c *gin.Context) *client.Contract {
	channel := c.Param("channel")
	ccname := c.Param("ccname")

	// Fallback to defaults if params are missing (for backward compatibility)
	if channel == "" {
		channel = os.Getenv("CHANNEL_NAME")
	}
	if ccname == "" {
		ccname = os.Getenv("CHAINCODE_NAME")
	}

	return h.Gateway.GetNetwork(channel).GetContract(ccname)
}

func (h *AssetHandler) CreateAsset(c *gin.Context) {
	// Support both JSON and MultipartForm
	var id, color, size, owner, appraisedValue string
	var fileCID, fileName string

	if contentType := c.GetHeader("Content-Type"); contentType == "application/json" {
		var asset models.Asset
		if err := c.ShouldBindJSON(&asset); err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		id = asset.ID
		color = asset.Color
		size = fmt.Sprintf("%d", asset.Size)
		owner = asset.Owner
		appraisedValue = fmt.Sprintf("%d", asset.AppraisedValue)
	} else {
		id = c.PostForm("ID")
		color = c.PostForm("Color")
		size = c.PostForm("Size")
		owner = c.PostForm("Owner")
		appraisedValue = c.PostForm("AppraisedValue")

		// Handle File Upload
		file, header, err := c.Request.FormFile("file")
		if err == nil {
			defer file.Close()
			fileName = header.Filename
			// Upload to IPFS
			cid, err := h.IPFS.AddFile(fileName, file)
			if err != nil {
				c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload to IPFS: " + err.Error()})
				return
			}
			fileCID = cid
		}
	}

	contract := h.getContract(c)
	_, err := contract.Submit("CreateAsset",
		client.WithArguments(
			id,
			color,
			size,
			owner,
			fileCID,
			fileName,
		),
		client.WithTransient(map[string][]byte{
			"appraisedValue": []byte(appraisedValue),
		}),
	)

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to submit transaction: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"ID":       id,
		"FileCID":  fileCID,
		"FileName": fileName,
		"Status":   "Created",
	})
}

func (h *AssetHandler) ReadAsset(c *gin.Context) {
	id := c.Param("id")
	contract := h.getContract(c)

	evaluateResult, err := contract.EvaluateTransaction("ReadAsset", id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Failed to evaluate transaction: " + err.Error()})
		return
	}

	var asset models.Asset
	if err := json.Unmarshal(evaluateResult, &asset); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unmarshal result: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, asset)
}

func (h *AssetHandler) GetAllAssets(c *gin.Context) {
	contract := h.getContract(c)
	evaluateResult, err := contract.EvaluateTransaction("GetAllAssets")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to evaluate transaction: " + err.Error()})
		return
	}

	var assets []models.Asset
	if err := json.Unmarshal(evaluateResult, &assets); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unmarshal result: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, assets)
}

func (h *AssetHandler) QueryAssets(c *gin.Context) {
	queryString := c.Query("query")
	if queryString == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "query parameter is required"})
		return
	}

	contract := h.getContract(c)
	evaluateResult, err := contract.EvaluateTransaction("QueryAssets", queryString)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to evaluate transaction: " + err.Error()})
		return
	}

	var assets []models.Asset
	if err := json.Unmarshal(evaluateResult, &assets); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unmarshal result: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, assets)
}

func (h *AssetHandler) ReadAssetFromBridge(c *gin.Context) {
	targetChannel := c.Param("targetChannel")
	assetID := c.Param("id")

	contract := h.getContract(c)
	evaluateResult, err := contract.EvaluateTransaction("ReadAssetFromChannel", targetChannel, assetID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Failed to bridge query: " + err.Error()})
		return
	}

	var asset models.Asset
	if err := json.Unmarshal(evaluateResult, &asset); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unmarshal result: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, asset)
}
