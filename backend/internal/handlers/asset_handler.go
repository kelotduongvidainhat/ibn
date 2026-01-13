package handlers

import (
	"encoding/json"
	"fmt"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/ibn/backend/internal/models"
)

type AssetHandler struct {
	Contract *client.Contract
}

func (h *AssetHandler) CreateAsset(c *gin.Context) {
	var asset models.Asset
	if err := c.ShouldBindJSON(&asset); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	_, err := h.Contract.SubmitTransaction("CreateAsset",
		asset.ID,
		asset.Color,
		fmt.Sprintf("%d", asset.Size),
		asset.Owner,
		fmt.Sprintf("%d", asset.AppraisedValue))

	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to submit transaction: " + err.Error()})
		return
	}

	c.JSON(http.StatusCreated, asset)
}

func (h *AssetHandler) ReadAsset(c *gin.Context) {
	id := c.Param("id")

	evaluateResult, err := h.Contract.EvaluateTransaction("ReadAsset", id)
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
