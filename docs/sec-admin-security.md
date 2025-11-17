mkdir -p docs

cat > docs/sec-admin-security.md << 'EOF'
# Admin Security Hardening (`admin.local` + `/admin`)

This document describes how the admin surface of the CPEmon MVP is protected.  
The goal is to make the admin UI accessible **only** from trusted locations and **only** for authenticated users.

---

## 1. Scope and Threat Model

### 1.1 What is the admin surface?

- **Endpoint**: `/admin` in the `cpemon-api` service.
- **Host**: exposed externally via the Ingress host **`admin.local`**.
- **Functionality**:
  - Search CPE by serial number (SN).
  - Show current status and recent history.
  - Provide shortcuts to observability tools (Grafana, Kibana).

### 1.2 Threat model (simplified)

Main risks we want to reduce:

1. **Unauthorized access from the Internet or lab network**  
   Someone discovers the admin host and tries to access `/admin`.

2. **Credential guessing / brute force on the admin endpoint**  
   If the admin is publicly reachable, an attacker could brute-force HTTP Basic Auth credentials.

3. **Accidental exposure during demos**  
   When running demos from a shared or unstable environment, we want a quick way to limit access.

To address these risks, we secured the admin surface at **two layers**:

- Network/edge layer: Ingress IP whitelist (who can even reach `/admin`).
- Application layer: HTTP Basic Auth (who can see the admin UI).

---

## 2. Application-Layer Protection: HTTP Basic Auth

### 2.1 Design

The `/admin` endpoint is implemented in `cpemon-api` (Gin).  
We enable HTTP Basic Auth only when **both** environment variables are set:

- `ADMIN_USER`
- `ADMIN_PASSWORD`

This allows us to:

- Protect `/admin` in production and demos.
- Run without auth in local/dev environments if needed (by not setting these env variables).

### 2.2 Implementation (Go / Gin extract)

```go
adminUser := os.Getenv("ADMIN_USER")
adminPass := os.Getenv("ADMIN_PASSWORD")
useAdminAuth := adminUser != "" && adminPass != ""

if useAdminAuth {
    log.Printf("[admin] /admin protected with Basic Auth, user=%s", adminUser)

    accounts := gin.Accounts{
        adminUser: adminPass,
    }
    authorized := r.Group("/", gin.BasicAuth(accounts))
    authorized.GET("/admin", handleAdmin)
    authorized.HEAD("/admin", handleAdmin)
} else {
    log.Printf("[admin] WARNING: ADMIN_USER or ADMIN_PASSWORD not set, /admin is NOT protected")

    r.GET("/admin", handleAdmin)
    r.HEAD("/admin", handleAdmin)
}

