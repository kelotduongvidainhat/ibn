package handlers

import (
	"fmt"
	"net/http"
	"os"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/hyperledger/fabric-gateway/pkg/client"
	"github.com/hyperledger/fabric-protos-go-apiv2/common"
	"google.golang.org/protobuf/proto"
)

type BlockHandler struct {
	Gateway *client.Gateway
}

func (h *BlockHandler) getQSCC(c *gin.Context) (*client.Contract, string) {
	channel := c.Param("channel")
	if channel == "" {
		channel = os.Getenv("CHANNEL_NAME")
	}
	if channel == "" {
		channel = "mychannel"
	}
	return h.Gateway.GetNetwork(channel).GetContract("qscc"), channel
}

// GetChainInfo returns the current height and hashes of the blockchain
func (h *BlockHandler) GetChainInfo(c *gin.Context) {
	contract, channel := h.getQSCC(c)

	evaluateResult, err := contract.EvaluateTransaction("GetChainInfo", channel)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get chain info: " + err.Error()})
		return
	}

	chainInfo := &common.BlockchainInfo{}
	if err := proto.Unmarshal(evaluateResult, chainInfo); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unmarshal chain info: " + err.Error()})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"height":            chainInfo.Height,
		"currentBlockHash":  fmt.Sprintf("%x", chainInfo.CurrentBlockHash),
		"previousBlockHash": fmt.Sprintf("%x", chainInfo.PreviousBlockHash),
	})
}

// GetBlockByNumber returns detailed info about a specific block
func (h *BlockHandler) GetBlockByNumber(c *gin.Context) {
	contract, channel := h.getQSCC(c)
	blockNumStr := c.Param("number")
	
	blockNum, err := strconv.ParseUint(blockNumStr, 10, 64)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid block number: " + err.Error()})
		return
	}

	evaluateResult, err := contract.EvaluateTransaction("GetBlockByNumber", channel, strconv.FormatUint(blockNum, 10))
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get block: " + err.Error()})
		return
	}

	block := &common.Block{}
	if err := proto.Unmarshal(evaluateResult, block); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to unmarshal block: " + err.Error()})
		return
	}

	// Extract some useful info for the visualizer
	txCount := len(block.Data.Data)
	
	c.JSON(http.StatusOK, gin.H{
		"number":          block.Header.Number,
		"data_hash":       fmt.Sprintf("%x", block.Header.DataHash),
		"previous_hash":   fmt.Sprintf("%x", block.Header.PreviousHash),
		"transaction_count": txCount,
	})
}
