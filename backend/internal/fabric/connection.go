package fabric

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"os"

	"github.com/hyperledger/fabric-gateway/pkg/identity"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

// NewGrpcConnection establishes a gRPC connection to the Fabric Peer using Mutual TLS
func NewGrpcConnection() (*grpc.ClientConn, error) {
	tlsCertPath := os.Getenv("TLS_CERT_PATH")
	peerEndpoint := os.Getenv("PEER_ENDPOINT")
	gatewayHost := os.Getenv("PEER_HOST_OVERRIDE")

	// Identity paths for Client Authentication (mTLS)
	clientCertPath := os.Getenv("CLIENT_TLS_CERT_PATH")
	clientKeyPath := os.Getenv("CLIENT_TLS_KEY_PATH")

	caCertificate, err := os.ReadFile(tlsCertPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read TLS CA certificate: %w", err)
	}

	certPool := x509.NewCertPool()
	certPool.AppendCertsFromPEM(caCertificate)

	var transportCredentials credentials.TransportCredentials
	if clientCertPath != "" && clientKeyPath != "" {
		cert, err := tls.LoadX509KeyPair(clientCertPath, clientKeyPath)
		if err != nil {
			return nil, fmt.Errorf("failed to load client TLS key pair: %w", err)
		}
		transportCredentials = credentials.NewTLS(&tls.Config{
			RootCAs:      certPool,
			Certificates: []tls.Certificate{cert},
			ServerName:   gatewayHost,
		})
	} else {
		transportCredentials = credentials.NewClientTLSFromCert(certPool, gatewayHost)
	}

	connection, err := grpc.Dial(peerEndpoint, grpc.WithTransportCredentials(transportCredentials))
	if err != nil {
		return nil, fmt.Errorf("failed to create gRPC connection: %w", err)
	}

	return connection, nil
}

// NewIdentity creates a client identity from the certificate
func NewIdentity() (*identity.X509Identity, error) {
	certPath := os.Getenv("CERT_PATH")
	mspID := os.Getenv("MSP_ID")

	certificatePEM, err := os.ReadFile(certPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read certificate: %w", err)
	}

	certificate, err := identity.CertificateFromPEM(certificatePEM)
	if err != nil {
		return nil, fmt.Errorf("failed to parse certificate: %w", err)
	}

	id, err := identity.NewX509Identity(mspID, certificate)
	if err != nil {
		return nil, err
	}

	return id, nil
}

// NewSign creates a function that can sign transactions
func NewSign() (identity.Sign, error) {
	keyPath := os.Getenv("KEY_PATH")

	privateKeyPEM, err := os.ReadFile(keyPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read private key: %w", err)
	}

	privateKey, err := identity.PrivateKeyFromPEM(privateKeyPEM)
	if err != nil {
		return nil, fmt.Errorf("failed to parse private key: %w", err)
	}

	return identity.NewPrivateKeySign(privateKey)
}
