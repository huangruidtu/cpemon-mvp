package db

import (
	"log"
	"time"

	"github.com/jmoiron/sqlx"
	_ "github.com/go-sql-driver/mysql" // MySQL driver
)

var globalDB *sqlx.DB

// Init initializes the global *sqlx.DB connection with some sane defaults.
func Init(dsn string) error {
	db, err := sqlx.Open("mysql", dsn)
	if err != nil {
		return err
	}

	// Connection pool settings (you can tune these later)
	db.SetMaxOpenConns(20)
	db.SetMaxIdleConns(10)
	db.SetConnMaxLifetime(30 * time.Minute)

	// Verify connection is actually working
	if err := db.Ping(); err != nil {
		_ = db.Close()
		return err
	}

	globalDB = db
	log.Println("database connection established")
	return nil
}

// Get returns the global *sqlx.DB. It will be nil if Init was not called.
func Get() *sqlx.DB {
	return globalDB
}
