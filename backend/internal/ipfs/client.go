package ipfs

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"mime/multipart"
	"net/http"
	"os"
)

type Client struct {
	BaseURL string
}

func NewClient() *Client {
	url := os.Getenv("IPFS_API_URL")
	if url == "" {
		url = "http://localhost:5001"
	}
	return &Client{BaseURL: url}
}

type AddResponse struct {
	Name string `json:"Name"`
	Hash string `json:"Hash"`
	Size string `json:"Size"`
}

func (c *Client) AddFile(fileName string, fileContent io.Reader) (string, error) {
	url := fmt.Sprintf("%s/api/v0/add", c.BaseURL)

	body := &bytes.Buffer{}
	writer := multipart.NewWriter(body)
	part, err := writer.CreateFormFile("file", fileName)
	if err != nil {
		return "", err
	}
	_, err = io.Copy(part, fileContent)
	if err != nil {
		return "", err
	}
	writer.Close()

	req, err := http.NewRequest("POST", url, body)
	if err != nil {
		return "", err
	}
	req.Header.Set("Content-Type", writer.FormDataContentType())

	httpClient := &http.Client{}
	resp, err := httpClient.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		respBody, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("IPFS error: %s", string(respBody))
	}

	var addResp AddResponse
	if err := json.NewDecoder(resp.Body).Decode(&addResp); err != nil {
		return "", err
	}

	return addResp.Hash, nil
}
