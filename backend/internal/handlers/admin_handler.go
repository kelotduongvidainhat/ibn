package handlers

import (
	"net/http"
	"os/exec"
	"path/filepath"
	"runtime"

	"github.com/gin-gonic/gin"
)

type AdminHandler struct {
	ScriptsDir string
}

func NewAdminHandler() *AdminHandler {
	// Dynamically find the project root and scripts directory
	_, b, _, _ := runtime.Caller(0)
	basepath := filepath.Dir(b)
	scriptsDir := filepath.Join(basepath, "..", "..", "..", "network", "scripts")

	return &AdminHandler{
		ScriptsDir: scriptsDir,
	}
}

func (h *AdminHandler) RunHealthCheck(c *gin.Context) {
	scriptPath := filepath.Join(h.ScriptsDir, "network-health.sh")
	cmd := exec.Command("/bin/bash", scriptPath, "mychannel")

	output, err := cmd.CombinedOutput()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":  err.Error(),
			"output": string(output),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Health check completed",
		"output":  string(output),
	})
}

func (h *AdminHandler) GetResourceUsage(c *gin.Context) {
	// Note: We use the interactive script but without the loop logic
	// or we can just call 'docker stats' directly for a single snapshot
	cmd := exec.Command("docker", "stats", "--no-stream", "--format", "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}")

	output, err := cmd.CombinedOutput()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":  err.Error(),
			"output": string(output),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"output": string(output),
	})
}

type ChaincodeOpRequest struct {
	Name     string `json:"name" binding:"required"`
	Version  string `json:"version" binding:"required"`
	Sequence string `json:"sequence" binding:"required"`
	Channel  string `json:"channel"`
}

func (h *AdminHandler) MassApprove(c *gin.Context) {
	var req ChaincodeOpRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.Channel == "" {
		req.Channel = "mychannel"
	}

	scriptPath := filepath.Join(h.ScriptsDir, "mass-approve.sh")
	cmd := exec.Command("/bin/bash", scriptPath, req.Name, req.Version, req.Sequence, req.Channel)

	output, err := cmd.CombinedOutput()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":  err.Error(),
			"output": string(output),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Mass approval triggered successfully",
		"output":  string(output),
	})
}

func (h *AdminHandler) MassCommit(c *gin.Context) {
	var req ChaincodeOpRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.Channel == "" {
		req.Channel = "mychannel"
	}

	scriptPath := filepath.Join(h.ScriptsDir, "mass-commit.sh")
	cmd := exec.Command("/bin/bash", scriptPath, req.Name, req.Version, req.Sequence, req.Channel)

	output, err := cmd.CombinedOutput()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":  err.Error(),
			"output": string(output),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Mass commit triggered successfully",
		"output":  string(output),
	})
}

type ChannelRequest struct {
	Name string `json:"name" binding:"required"`
}

func (h *AdminHandler) CreateChannel(c *gin.Context) {
	var req ChannelRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	scriptPath := filepath.Join(h.ScriptsDir, "create-channel.sh")
	cmd := exec.Command("/bin/bash", scriptPath, req.Name)

	output, err := cmd.CombinedOutput()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":  err.Error(),
			"output": string(output),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Channel created successfully",
		"output":  string(output),
	})
}

type ChaincodeUpgradeRequest struct {
	Name    string `json:"name" binding:"required"`
	Channel string `json:"channel"`
}

func (h *AdminHandler) UpgradeChaincode(c *gin.Context) {
	var req ChaincodeUpgradeRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.Channel == "" {
		req.Channel = "mychannel"
	}

	scriptPath := filepath.Join(h.ScriptsDir, "upgrade-cc.sh")
	cmd := exec.Command("/bin/bash", scriptPath, req.Name, req.Channel)

	output, err := cmd.CombinedOutput()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error":  err.Error(),
			"output": string(output),
		})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message": "Chaincode upgraded successfully",
		"output":  string(output),
	})
}
