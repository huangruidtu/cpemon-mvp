package hmac

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
)

// ComputeSHA256Hex computes an HMAC-SHA256 signature of "data" using "secret"
// and returns it as a lowercase hex string.
func ComputeSHA256Hex(data []byte, secret string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write(data)
	sum := mac.Sum(nil)
	return hex.EncodeToString(sum)
}

// VerifySHA256Hex checks whether the given signature (hex string) matches
// the expected HMAC-SHA256 of data and secret.
func VerifySHA256Hex(data []byte, secret string, signature string) bool {
	expected := ComputeSHA256Hex(data, secret)
	// hmac.Equal does a constant-time comparison to avoid timing attacks.
	return hmac.Equal([]byte(expected), []byte(signature))
}
