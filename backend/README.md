# Backend API (Fabric Gateway)

This refined backend service provides a RESTful interface to the Asset Management blockchain.

## 🚀 Features
- **Fabric Gateway SDK**: Uses the modern v1.x client.
- **RESTful Endpoints**: Built with Gin framework.
- **CORS Enabled**: Ready for frontend integration.
- **Environment Driven**: Configurable via `.env`.

## 🛠️ Prerequisites
- Go 1.23+
- A running Fabric network (run `./network/scripts/bootstrap-ca.sh` first).

## 🏃 Running the API
1. Install dependencies:
   ```bash
   go mod tidy
   ```
2. Start the server:
   ```bash
   go run main.go
   ```

## 📝 API Reference

### Create Asset
- **URL**: `POST /api/assets`
- **Body**:
  ```json
  {
    "ID": "asset2",
    "Color": "red",
    "Size": 10,
    "Owner": "Alice",
    "AppraisedValue": 500
  }
  ```

### Read Asset
- **URL**: `GET /api/assets/:id`
- **Response**:
  ```json
  {
    "ID": "asset2",
    "Color": "red",
    "Size": 10,
    "Owner": "Alice",
    "AppraisedValue": 500
  }
  ```

## 🏗️ Folder Structure
- `internal/fabric`: Gateway connection and identity logic.
- `internal/handlers`: REST controllers.
- `internal/models`: Data structures.
