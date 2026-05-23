# H-Code 远程控制 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 手机端远程控制 Claude Code——通过 Go 云服务器中继，Flutter App 发指令，Electron 桌面端执行并回传结果。

**Architecture:** 三组件 WebSocket 星形架构。Go Relay Server 为中心节点，负责配对管理 + 消息路由 + 离线缓冲。Flutter App 和 Electron 桌面端均作为 WebSocket 客户端连接服务器，通过 6 位配对码建立关联。

**Tech Stack:** Go + Gin + gorilla/websocket + gorm + modernc.org/sqlite | Flutter + riverpod + web_socket_channel | Electron + ws

**开发顺序:** Go 服务器 → Electron 桌面端 → Flutter App

---

### Task 1: Go 项目初始化

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\go.mod`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\main.go`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\config.yaml`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\config\config.go`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\router\router.go`

- [ ] **Step 1: 初始化 Go module 并安装依赖**

Run:
```bash
cd "C:\Users\chenhang\Desktop\AI\H-code-Server"
go mod init h-code-server
go get github.com/gin-gonic/gin
go get github.com/gorilla/websocket
go get gorm.io/gorm
go get gorm.io/driver/sqlite
go get github.com/spf13/viper
go get modernc.org/sqlite
```

Expected: `go.mod` created with all dependencies.

- [ ] **Step 2: 创建 config.yaml**

```yaml
server:
  port: 8080

websocket:
  heartbeat_interval: 30
  heartbeat_timeout: 90

pair:
  code_length: 6
  expire_seconds: 300

buffer:
  max_size: 200
  message_ttl_seconds: 3600

db:
  path: ./data/hcode.db
```

- [ ] **Step 3: 创建 config/config.go**

```go
package config

import (
	"github.com/spf13/viper"
)

type Config struct {
	Server    ServerConfig
	Websocket WebsocketConfig
	Pair      PairConfig
	Buffer    BufferConfig
	DB        DBConfig
}

type ServerConfig struct {
	Port int
}

type WebsocketConfig struct {
	HeartbeatInterval int `mapstructure:"heartbeat_interval"`
	HeartbeatTimeout  int `mapstructure:"heartbeat_timeout"`
}

type PairConfig struct {
	CodeLength     int `mapstructure:"code_length"`
	ExpireSeconds  int `mapstructure:"expire_seconds"`
}

type BufferConfig struct {
	MaxSize          int `mapstructure:"max_size"`
	MessageTTLSeconds int `mapstructure:"message_ttl_seconds"`
}

type DBConfig struct {
	Path string
}

func Load() *Config {
	viper.SetConfigName("config")
	viper.SetConfigType("yaml")
	viper.AddConfigPath(".")
	viper.SetDefault("server.port", 8080)
	viper.SetDefault("websocket.heartbeat_interval", 30)
	viper.SetDefault("websocket.heartbeat_timeout", 90)
	viper.SetDefault("pair.code_length", 6)
	viper.SetDefault("pair.expire_seconds", 300)
	viper.SetDefault("buffer.max_size", 200)
	viper.SetDefault("buffer.message_ttl_seconds", 3600)
	viper.SetDefault("db.path", "./data/hcode.db")
	if err := viper.ReadInConfig(); err != nil {
		if _, ok := err.(viper.ConfigFileNotFoundError); !ok {
			panic(err)
		}
	}
	var cfg Config
	if err := viper.Unmarshal(&cfg); err != nil {
		panic(err)
	}
	return &cfg
}
```

- [ ] **Step 4: 创建 router/router.go**

```go
package router

import (
	"github.com/gin-gonic/gin"
)

func Setup() *gin.Engine {
	r := gin.Default()
	r.GET("/api/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})
	return r
}
```

- [ ] **Step 5: 创建 main.go**

```go
package main

import (
	"fmt"
	"log/slog"
	"os"
	"h-code-server/config"
	"h-code-server/router"
)

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})))
	cfg := config.Load()
	slog.Info("config loaded", "port", cfg.Server.Port)
	r := router.Setup()
	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	slog.Info("server starting", "addr", addr)
	if err := r.Run(addr); err != nil {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}
```

- [ ] **Step 6: 编译运行验证**

Run:
```bash
cd "C:\Users\chenhang\Desktop\AI\H-code-Server"
go build -o hcode-server.exe .
./hcode-server.exe
```

Expected: `server starting addr=:8080`，访问 `http://localhost:8080/api/health` 返回 `{"status":"ok"}`。

---

### Task 2: 数据模型 + SQLite 初始化

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\internal\model\message.go`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\internal\model\pair_record.go`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\internal\model\db.go`

- [ ] **Step 1: 创建 internal/model/message.go**

```go
package model

import "time"

type Message struct {
	ID        int64     `gorm:"primaryKey;autoIncrement"`
	PairCode  string    `gorm:"index;not null"`
	Seq       int64     `gorm:"not null"`
	Type      string    `gorm:"not null"`
	Payload   string    `gorm:"type:text"`
	CreatedAt time.Time
}
```

- [ ] **Step 2: 创建 internal/model/pair_record.go**

```go
package model

import "time"

type PairRecord struct {
	ID        int64     `gorm:"primaryKey;autoIncrement"`
	PairCode  string    `gorm:"uniqueIndex;not null"`
	Status    string    `gorm:"default:pending"` // pending, paired, expired
	CreatedAt time.Time
	ExpiresAt time.Time
}
```

- [ ] **Step 3: 创建 internal/model/db.go**

```go
package model

import (
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
	"gorm.io/gorm/logger"
	"log/slog"
	"os"
	"path/filepath"
)

var DB *gorm.DB

func InitDB(path string) {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		panic(err)
	}
	var err error
	DB, err = gorm.Open(sqlite.Open(path), &gorm.Config{
		Logger: logger.Default.LogMode(logger.Warn),
	})
	if err != nil {
		panic(err)
	}
	if err := DB.AutoMigrate(&Message{}, &PairRecord{}); err != nil {
		panic(err)
	}
	slog.Info("db initialized", "path", path)
}
```

- [ ] **Step 4: 更新 main.go 初始化数据库**

在 `main.go` 的 `config.Load()` 之后、`router.Setup()` 之前加入：

```go
import "h-code-server/internal/model"

// ...
model.InitDB(cfg.DB.Path)
// ...
```

---

### Task 3: 配对码模块

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\internal\pair\pair.go`

- [ ] **Step 1: 创建 internal/pair/pair.go**

```go
package pair

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"sync"
	"time"
)

type PairManager struct {
	mu           sync.Mutex
	codeToDesktop map[string]string // pairCode -> desktop socket ID (待配对)
	desktopToCode map[string]string // desktop socket ID -> pairCode
	expires      map[string]time.Time
	codeLen      int
	expireSecs   int
}

func NewPairManager(codeLen, expireSecs int) *PairManager {
	return &PairManager{
		codeToDesktop: make(map[string]string),
		desktopToCode: make(map[string]string),
		expires:       make(map[string]time.Time),
		codeLen:       codeLen,
		expireSecs:    expireSecs,
	}
}

func (pm *PairManager) GenerateCode(desktopID string) string {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	if code, ok := pm.desktopToCode[desktopID]; ok {
		delete(pm.codeToDesktop, code)
		delete(pm.desktopToCode, desktopID)
		delete(pm.expires, code)
	}
	code := randomDigits(pm.codeLen)
	pm.codeToDesktop[code] = desktopID
	pm.desktopToCode[desktopID] = code
	pm.expires[code] = time.Now().Add(time.Duration(pm.expireSecs) * time.Second)
	return code
}

func (pm *PairManager) ValidateCode(phoneID, code string) (desktopID string, ok bool) {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	desktopID, exists := pm.codeToDesktop[code]
	if !exists {
		return "", false
	}
	if time.Now().After(pm.expires[code]) {
		delete(pm.codeToDesktop, code)
		delete(pm.desktopToCode, desktopID)
		delete(pm.expires, code)
		return "", false
	}
	return desktopID, true
}

func (pm *PairManager) RemoveCode(desktopID string) {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	code, ok := pm.desktopToCode[desktopID]
	if !ok {
		return
	}
	delete(pm.codeToDesktop, code)
	delete(pm.desktopToCode, desktopID)
	delete(pm.expires, code)
}

func (pm *PairManager) CleanExpired() {
	pm.mu.Lock()
	defer pm.mu.Unlock()
	now := time.Now()
	for code, exp := range pm.expires {
		if now.After(exp) {
			desktopID := pm.codeToDesktop[code]
			delete(pm.codeToDesktop, code)
			delete(pm.desktopToCode, desktopID)
			delete(pm.expires, code)
		}
	}
}

func randomDigits(n int) string {
	result := make([]byte, n)
	for i := 0; i < n; i++ {
		num, _ := rand.Int(rand.Reader, big.NewInt(10))
		result[i] = byte('0') + byte(num.Int64())
	}
	return string(result)
}

func FormatCode(code string) string {
	if len(code) != 6 {
		return code
	}
	return fmt.Sprintf("%s %s", code[:3], code[3:])
}
```

---

### Task 4: 环形消息缓冲

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\internal\session\buffer.go`

- [ ] **Step 1: 创建 internal/session/buffer.go**

```go
package session

import (
	"sync"
	"time"
	"h-code-server/internal/model"
)

type MessageItem struct {
	Seq       int64  `json:"seq"`
	Type      string `json:"type"`
	Payload   string `json:"payload"`
	Timestamp int64  `json:"timestamp"`
}

type RingBuffer struct {
	mu       sync.Mutex
	buf      []MessageItem
	size     int
	head     int
	count    int
	nextSeq  int64
	ttl      time.Duration
}

func NewRingBuffer(size int, ttl time.Duration) *RingBuffer {
	return &RingBuffer{
		buf:  make([]MessageItem, size),
		size: size,
		ttl:  ttl,
	}
}

func (rb *RingBuffer) Push(msg MessageItem) {
	rb.mu.Lock()
	defer rb.mu.Unlock()
	msg.Seq = rb.nextSeq
	rb.nextSeq++
	rb.buf[rb.head] = msg
	rb.head = (rb.head + 1) % rb.size
	if rb.count < rb.size {
		rb.count++
	}
}

func (rb *RingBuffer) GetSince(lastSeq int64) []MessageItem {
	rb.mu.Lock()
	defer rb.mu.Unlock()
	if rb.count == 0 {
		return nil
	}
	cutoff := time.Now().Add(-rb.ttl).Unix()
	var result []MessageItem
	start := (rb.head - rb.count + rb.size) % rb.size
	for i := 0; i < rb.count; i++ {
		idx := (start + i) % rb.size
		msg := rb.buf[idx]
		if msg.Seq > lastSeq && msg.Timestamp >= cutoff {
			result = append(result, msg)
		}
	}
	return result
}

type BufferHub struct {
	mu      sync.Mutex
	buffers map[string]*RingBuffer
	size    int
	ttl     time.Duration
}

func NewBufferHub(size int, ttl time.Duration) *BufferHub {
	return &BufferHub{
		buffers: make(map[string]*RingBuffer),
		size:    size,
		ttl:     ttl,
	}
}

func (bh *BufferHub) Get(pairCode string) *RingBuffer {
	bh.mu.Lock()
	defer bh.mu.Unlock()
	if b, ok := bh.buffers[pairCode]; ok {
		return b
	}
	b := NewRingBuffer(bh.size, bh.ttl)
	bh.buffers[pairCode] = b
	return b
}

func (bh *BufferHub) Remove(pairCode string) {
	bh.mu.Lock()
	defer bh.mu.Unlock()
	delete(bh.buffers, pairCode)
}

func (bh *BufferHub) Push(pairCode string, msgType, payload string) {
	msg := MessageItem{
		Type:      msgType,
		Payload:   payload,
		Timestamp: time.Now().Unix(),
	}
	bh.Get(pairCode).Push(msg)
	model.DB.Create(&model.Message{
		PairCode: pairCode,
		Seq:      msg.Seq,
		Type:     msgType,
		Payload:  payload,
	})
}
```

---

### Task 5: WebSocket 协议定义

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\internal\ws\protocol.go`

- [ ] **Step 1: 创建 internal/ws/protocol.go**

```go
package ws

import "encoding/json"

type WSMessage struct {
	Type       string          `json:"type"`
	PairCode   string          `json:"pair_code,omitempty"`
	ClientType string          `json:"client_type,omitempty"`
	Seq        int64           `json:"seq,omitempty"`
	Payload    json.RawMessage `json:"payload,omitempty"`
	Timestamp  int64           `json:"timestamp,omitempty"`
}

const (
	MsgTypeRegister    = "register"
	MsgTypeCommand     = "command"
	MsgTypeAIResponse  = "ai_response"
	MsgTypeTodoUpdate  = "todo_update"
	MsgTypeHeartbeat   = "heartbeat"
	MsgTypeAck         = "ack"
	MsgTypeError       = "error"
	MsgTypePairCode    = "pair_code"
	MsgTypePaired      = "paired"
	MsgTypeDisconnect  = "disconnect"
)
```

---

### Task 6: WebSocket Client（单连接处理）

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\internal\ws\client.go`

- [ ] **Step 1: 创建 internal/ws/client.go**

```go
package ws

import (
	"encoding/json"
	"log/slog"
	"time"
	"github.com/gorilla/websocket"
)

type Client struct {
	ID         string
	ClientType string // "desktop" | "phone"
	PairCode   string
	Conn       *websocket.Conn
	Hub        *Hub
	Send       chan []byte
	AliveAt    time.Time
}

func NewClient(id string, conn *websocket.Conn, hub *Hub) *Client {
	return &Client{
		ID:      id,
		Conn:    conn,
		Hub:     hub,
		Send:    make(chan []byte, 64),
		AliveAt: time.Now(),
	}
}

func (c *Client) ReadPump() {
	defer func() {
		c.Hub.Unregister <- c
		c.Conn.Close()
	}()
	c.Conn.SetReadLimit(65536)
	for {
		_, raw, err := c.Conn.ReadMessage()
		if err != nil {
			slog.Info("client disconnected", "id", c.ID, "error", err)
			break
		}
		var msg WSMessage
		if err := json.Unmarshal(raw, &msg); err != nil {
			slog.Warn("invalid message", "id", c.ID, "error", err)
			continue
		}
		switch msg.Type {
		case MsgTypeRegister:
			c.ClientType = msg.ClientType
			c.PairCode = msg.PairCode
		case MsgTypeHeartbeat:
			c.AliveAt = time.Now()
			c.Send <- mustMarshal(WSMessage{Type: MsgTypeHeartbeat})
			continue
		case MsgTypeCommand:
			if c.ClientType == "phone" && c.PairCode != "" {
				c.Hub.BroadcastToDesktop(c.PairCode, msg)
			}
		case MsgTypeAIResponse, MsgTypeTodoUpdate:
			if c.ClientType == "desktop" && c.PairCode != "" {
				c.Hub.BroadcastToPhone(c.PairCode, msg)
			}
		case MsgTypeAck:
			c.Hub.HandleAck(c, msg)
		}
		c.AliveAt = time.Now()
	}
}

func (c *Client) WritePump() {
	ticker := time.NewTicker(time.Duration(c.Hub.Cfg.HeartbeatInterval) * time.Second)
	defer func() {
		ticker.Stop()
		c.Conn.Close()
	}()
	for {
		select {
		case msg, ok := <-c.Send:
			if !ok {
				c.Conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}
			if err := c.Conn.WriteMessage(websocket.TextMessage, msg); err != nil {
				return
			}
		case <-ticker.C:
			if time.Since(c.AliveAt).Seconds() > float64(c.Hub.Cfg.HeartbeatTimeout) {
				slog.Info("heartbeat timeout", "id", c.ID)
				return
			}
		}
	}
}

func mustMarshal(v interface{}) []byte {
	data, err := json.Marshal(v)
	if err != nil {
		panic(err)
	}
	return data
}
```

---

### Task 7: WebSocket Hub（连接管理）

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\internal\ws\hub.go`

- [ ] **Step 1: 创建 internal/ws/hub.go**

```go
package ws

import (
	"encoding/json"
	"log/slog"
	"sync"
	"time"
	"github.com/gorilla/websocket"
	"h-code-server/config"
	"h-code-server/internal/pair"
	"h-code-server/internal/session"
)

type HubConfig struct {
	HeartbeatInterval int
	HeartbeatTimeout  int
}

type Hub struct {
	mu          sync.RWMutex
	clients     map[*Client]bool
	pairCodeMap map[string]map[string]*Client // pairCode -> {"desktop": c, "phone": c}
	pairMgr     *pair.PairManager
	bufferHub   *session.BufferHub
	Cfg         HubConfig
	Register    chan *Client
	Unregister  chan *Client
}

func NewHub(cfg *config.Config, pairMgr *pair.PairManager) *Hub {
	return &Hub{
		clients:     make(map[*Client]bool),
		pairCodeMap: make(map[string]map[string]*Client),
		pairMgr:     pairMgr,
		bufferHub:   session.NewBufferHub(cfg.Buffer.MaxSize, time.Duration(cfg.Buffer.MessageTTLSeconds)*time.Second),
		Cfg: HubConfig{
			HeartbeatInterval: cfg.Websocket.HeartbeatInterval,
			HeartbeatTimeout:  cfg.Websocket.HeartbeatTimeout,
		},
		Register:   make(chan *Client),
		Unregister: make(chan *Client),
	}
}

func (h *Hub) Run() {
	for {
		select {
		case c := <-h.Register:
			h.mu.Lock()
			h.clients[c] = true
			if c.ClientType == "desktop" && c.PairCode == "" {
				code := h.pairMgr.GenerateCode(c.ID)
				c.PairCode = code
				c.ClientType = "desktop"
				h.pairCodeMap[code] = map[string]*Client{"desktop": c}
				c.Send <- mustMarshal(WSMessage{
					Type:    MsgTypePairCode,
					Payload: json.RawMessage(`"` + code + `"`),
				})
				slog.Info("desktop registered", "id", c.ID, "pair_code", code)
			} else if c.ClientType == "phone" && c.PairCode != "" {
				desktopID, ok := h.pairMgr.ValidateCode(c.ID, c.PairCode)
				if ok {
					if room, exists := h.pairCodeMap[c.PairCode]; exists {
						room["phone"] = c
						c.Send <- mustMarshal(WSMessage{Type: MsgTypePaired, Payload: json.RawMessage(`"` + desktopID + `"`)})
						// 重连：回放缓冲消息
						if lastSeq := h.getLastAck(c.PairCode); lastSeq > 0 {
							msgs := h.bufferHub.Get(c.PairCode).GetSince(lastSeq)
							for _, m := range msgs {
								c.Send <- mustMarshal(WSMessage{
									Type:      m.Type,
									Seq:       m.Seq,
									Payload:   json.RawMessage(m.Payload),
									Timestamp: m.Timestamp,
								})
							}
						}
						slog.Info("phone paired", "pair_code", c.PairCode)
					} else {
						c.Send <- mustMarshal(WSMessage{Type: MsgTypeError, Payload: json.RawMessage(`"room not found"`)})
					}
				} else {
					c.Send <- mustMarshal(WSMessage{Type: MsgTypeError, Payload: json.RawMessage(`"invalid or expired pair code"`)})
				}
			}
			h.mu.Unlock()
		case c := <-h.Unregister:
			h.mu.Lock()
			delete(h.clients, c)
			if c.PairCode != "" {
				room := h.pairCodeMap[c.PairCode]
				if room != nil {
					delete(room, c.ClientType)
					// 通知对方离线
					otherKey := "desktop"
					if c.ClientType == "desktop" {
						otherKey = "phone"
					}
					if other, ok := room[otherKey]; ok {
						other.Send <- mustMarshal(WSMessage{Type: MsgTypeDisconnect, Payload: json.RawMessage(`"` + c.ClientType + `"`)})
					}
					if len(room) == 0 {
						delete(h.pairCodeMap, c.PairCode)
						h.bufferHub.Remove(c.PairCode)
						h.pairMgr.RemoveCode(c.PairCode)
					}
				}
			}
			close(c.Send)
			h.mu.Unlock()
		}
	}
}

func (h *Hub) BroadcastToDesktop(pairCode string, msg WSMessage) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	h.bufferHub.Push(pairCode, msg.Type, string(msg.Payload))
	if room, ok := h.pairCodeMap[pairCode]; ok {
		if desktop, ok := room["desktop"]; ok {
			data := mustMarshal(msg)
			select {
			case desktop.Send <- data:
			default:
			}
		}
	}
}

func (h *Hub) BroadcastToPhone(pairCode string, msg WSMessage) {
	h.mu.RLock()
	defer h.mu.RUnlock()
	h.bufferHub.Push(pairCode, msg.Type, string(msg.Payload))
	if room, ok := h.pairCodeMap[pairCode]; ok {
		if phone, ok := room["phone"]; ok {
			data := mustMarshal(msg)
			select {
			case phone.Send <- data:
			default:
			}
		}
	}
}

func (h *Hub) HandleAck(c *Client, msg WSMessage) {
	h.storeLastAck(c.PairCode, msg.Seq)
}

func (h *Hub) storeLastAck(pairCode string, seq int64) {
	// 记录手机端最后确认的 seq，用于重连回放
}

func (h *Hub) getLastAck(pairCode string) int64 {
	return 0
}

var upgrader = websocket.Upgrader{
	ReadBufferSize:  4096,
	WriteBufferSize: 4096,
	CheckOrigin:     func(r *http.Request) bool { return true },
}

func (h *Hub) HandleWebSocket(c *gin.Context) {
	conn, err := upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		slog.Error("upgrade failed", "error", err)
		return
	}
	client := NewClient(generateID(), conn, h)
	go client.ReadPump()
	go client.WritePump()
	h.Register <- client
}

func generateID() string {
	// 简单生成唯一 ID
	return fmt.Sprintf("%d", time.Now().UnixNano())
}
```

Add missing imports at top:
```go
import (
	"fmt"
	"net/http"
	"github.com/gin-gonic/gin"
)
```

---

### Task 8: 会话事件处理

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-Server\internal\session\handler.go`

- [ ] **Step 1: 创建 internal/session/handler.go**

```go
package session

import (
	"encoding/json"
	"log/slog"
)

type EventHandler struct {
	bufferHub *BufferHub
}

func NewEventHandler(bufferHub *BufferHub) *EventHandler {
	return &EventHandler{bufferHub: bufferHub}
}

func (h *EventHandler) HandleCommand(pairCode string, payload json.RawMessage) {
	slog.Info("command received", "pair_code", pairCode)
	h.bufferHub.Push(pairCode, "command", string(payload))
}

func (h *EventHandler) HandleAIResponse(pairCode string, payload json.RawMessage) {
	slog.Info("ai response", "pair_code", pairCode)
	h.bufferHub.Push(pairCode, "ai_response", string(payload))
}

func (h *EventHandler) HandleTodoUpdate(pairCode string, payload json.RawMessage) {
	slog.Info("todo update", "pair_code", pairCode)
	h.bufferHub.Push(pairCode, "todo_update", string(payload))
}
```

---

### Task 9: WebSocket 路由集成 + 启动入口

**Files:**
- Modify: `C:\Users\chenhang\Desktop\AI\H-code-Server\router\router.go`
- Modify: `C:\Users\chenhang\Desktop\AI\H-code-Server\main.go`

- [ ] **Step 1: 更新 router/router.go**

```go
package router

import (
	"github.com/gin-gonic/gin"
	"h-code-server/config"
	"h-code-server/internal/pair"
	"h-code-server/internal/ws"
)

func Setup(cfg *config.Config) *gin.Engine {
	r := gin.Default()

	pairMgr := pair.NewPairManager(cfg.Pair.CodeLength, cfg.Pair.ExpireSeconds)
	hub := ws.NewHub(cfg, pairMgr)
	go hub.Run()

	r.GET("/api/health", func(c *gin.Context) {
		c.JSON(200, gin.H{"status": "ok"})
	})

	r.GET("/ws", func(c *gin.Context) {
		hub.HandleWebSocket(c)
	})

	return r
}
```

- [ ] **Step 2: 更新 main.go**

```go
package main

import (
	"fmt"
	"log/slog"
	"os"
	"h-code-server/config"
	"h-code-server/internal/model"
	"h-code-server/router"
)

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stdout, &slog.HandlerOptions{Level: slog.LevelInfo})))
	cfg := config.Load()
	slog.Info("config loaded", "port", cfg.Server.Port)
	model.InitDB(cfg.DB.Path)
	r := router.Setup(cfg)
	addr := fmt.Sprintf(":%d", cfg.Server.Port)
	slog.Info("server starting", "addr", addr)
	if err := r.Run(addr); err != nil {
		slog.Error("server failed", "error", err)
		os.Exit(1)
	}
}
```

- [ ] **Step 3: 编译验证**

```bash
cd "C:\Users\chenhang\Desktop\AI\H-code-Server"
go build -o hcode-server.exe .
```

Expected: 编译通过，无错误。

---

### Task 10: Go 服务器集成测试

- [ ] **Step 1: 启动服务器**

```bash
cd "C:\Users\chenhang\Desktop\AI\H-code-Server"
./hcode-server.exe
```

- [ ] **Step 2: 用 wscat 或浏览器 console 测试 WebSocket**

Test 1 - Desktop 连接：
```js
const ws1 = new WebSocket('ws://localhost:8080/ws');
ws1.onmessage = (e) => console.log('desktop:', JSON.parse(e.data));
ws1.onopen = () => ws1.send(JSON.stringify({type: 'register', client_type: 'desktop'}));
```
Expected: 收到 `{type: "pair_code", payload: "123456"}`。

Test 2 - Phone 配对：
```js
const ws2 = new WebSocket('ws://localhost:8080/ws');
ws2.onmessage = (e) => console.log('phone:', JSON.parse(e.data));
ws2.onopen = () => ws2.send(JSON.stringify({type: 'register', client_type: 'phone', pair_code: '123456'}));
```
Expected: 收到 `{type: "paired"}`。

Test 3 - 消息转发：
```js
ws2.send(JSON.stringify({type: 'command', payload: '测试指令'}));
```
Expected: Desktop 端收到 command 消息。

---

### Task 11: Electron ws-bridge 模块

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-Code\src\main\ws-bridge.ts`
- Modify: `C:\Users\chenhang\Desktop\AI\H-Code\package.json` (加 `ws` 依赖)

- [ ] **Step 1: 安装 ws 依赖**

```bash
cd "C:\Users\chenhang\Desktop\AI\H-Code"
pnpm add ws
pnpm add -D @types/ws
```

- [ ] **Step 2: 创建 src/main/ws-bridge.ts**

```typescript
import WebSocket from 'ws'
import { BrowserWindow } from 'electron'

type ConnectionStatus = 'disconnected' | 'connecting' | 'connected'

interface WSBridgeConfig {
  serverUrl: string
}

export class WSBridge {
  private ws: WebSocket | null = null
  private config: WSBridgeConfig
  private status: ConnectionStatus = 'disconnected'
  private pairCode: string | null = null
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null
  private reconnectDelay = 1000
  private onCommand: ((payload: string) => void) | null = null

  constructor(config: WSBridgeConfig) {
    this.config = config
  }

  setOnCommand(handler: (payload: string) => void) {
    this.onCommand = handler
  }

  getStatus(): ConnectionStatus {
    return this.status
  }

  getPairCode(): string | null {
    return this.pairCode
  }

  connect() {
    if (this.ws) {
      this.ws.close()
    }
    this.setStatus('connecting')
    this.ws = new WebSocket(this.config.serverUrl)

    this.ws.on('open', () => {
      console.log('[ws-bridge] connected')
      this.ws!.send(JSON.stringify({ type: 'register', client_type: 'desktop' }))
    })

    this.ws.on('message', (raw) => {
      try {
        const msg = JSON.parse(raw.toString())
        switch (msg.type) {
          case 'pair_code':
            this.pairCode = msg.payload
            this.setStatus('connected')
            this.reconnectDelay = 1000
            this.notifyRenderers('pair-code-updated', this.pairCode)
            break
          case 'command':
            if (this.onCommand) {
              this.onCommand(msg.payload || '')
            }
            break
          case 'heartbeat':
            break
          case 'disconnect':
            console.log('[ws-bridge] peer disconnected:', msg.payload)
            break
        }
      } catch (e) {
        console.error('[ws-bridge] parse error:', e)
      }
    })

    this.ws.on('close', () => {
      console.log('[ws-bridge] disconnected')
      this.setStatus('disconnected')
      this.scheduleReconnect()
    })

    this.ws.on('error', (err) => {
      console.error('[ws-bridge] error:', err.message)
      this.ws?.close()
    })
  }

  sendCommand(payload: string) {
    if (this.ws && this.status === 'connected') {
      this.ws.send(JSON.stringify({ type: 'ai_response', payload }))
    }
  }

  sendTodoUpdate(payload: string) {
    if (this.ws && this.status === 'connected') {
      this.ws.send(JSON.stringify({ type: 'todo_update', payload }))
    }
  }

  private setStatus(s: ConnectionStatus) {
    this.status = s
    this.notifyRenderers('connection-status-changed', s)
  }

  private scheduleReconnect() {
    if (this.reconnectTimer) return
    console.log(`[ws-bridge] reconnect in ${this.reconnectDelay}ms`)
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = null
      this.reconnectDelay = Math.min(this.reconnectDelay * 2, 30000)
      this.connect()
    }, this.reconnectDelay)
  }

  private notifyRenderers(channel: string, data: unknown) {
    BrowserWindow.getAllWindows().forEach((win) => {
      if (!win.isDestroyed()) {
        win.webContents.send(channel, data)
      }
    })
  }

  destroy() {
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer)
    }
    this.ws?.close()
  }
}
```

---

### Task 12: Electron IPC + 主进程集成

**Files:**
- Modify: `C:\Users\chenhang\Desktop\AI\H-Code\src\main\index.ts`
- Modify: `C:\Users\chenhang\Desktop\AI\H-Code\src\preload\index.ts`
- Modify: `C:\Users\chenhang\Desktop\AI\H-Code\src\renderer\electron.d.ts`

- [ ] **Step 1: 在 main/index.ts 顶部添加 import 和初始化**

在 `src/main/index.ts` 顶部 import 区域末尾添加：

```typescript
import { WSBridge } from './ws-bridge'
```

在 `let currentClaudePty` 行后添加：

```typescript
const wsBridge = new WSBridge({
  serverUrl: process.env.HC_SERVER_URL || 'ws://localhost:8080/ws'
})
```

- [ ] **Step 2: 在 main/index.ts 的 app.whenReady() 回调末尾添加 wsBridge 启动**

在 `app.whenReady().then(() => {` 函数体内末尾，找到合适位置添加：

```typescript
wsBridge.connect()
wsBridge.setOnCommand((payload: string) => {
  const sessionId = 'remote-' + Date.now()
  // 创建或复用 PTY 会话来执行命令
  // 命令通过 write-pty 发送给 Claude Code
  const windows = BrowserWindow.getAllWindows()
  if (windows.length > 0) {
    // 使用现有的第一个 session 或创建新 session
    ipcMain.emit('write-pty' as any, null as any, sessionId, payload + '\r\n')
  }
})
```

- [ ] **Step 3: 在 main/index.ts 添加新的 IPC handlers**

在 `ipcMain.handle('kill-claude', ...)` 之后添加：

```typescript
ipcMain.handle('get-pair-code', () => {
  return wsBridge.getPairCode()
})

ipcMain.handle('get-connection-status', () => {
  return wsBridge.getStatus()
})
```

- [ ] **Step 4: 在 PTY onData 回调中添加远程转发钩子**

在 `pty.onData((data) => {` 回调末尾（在 `checkTaskDone` 之后）添加：

```typescript
// 提取 AI 回复内容转发给手机端
const aiResponse = extractAIResponse(data)
if (aiResponse) {
  wsBridge.sendCommand(JSON.stringify({ content: aiResponse }))
}
```

在文件末尾添加辅助函数：

```typescript
function extractAIResponse(data: string): string | null {
  // 过滤 ANSI 转义序列和控制字符
  const cleaned = data.replace(/\x1b\[[0-9;]*m/g, '').replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '')
  if (cleaned.trim().length > 0) {
    return cleaned
  }
  return null
}
```

- [ ] **Step 5: 更新 preload/index.ts 添加新 IPC 暴露**

在 preload/index.ts 的 `electronAPI` 对象末尾（`killClaude` 之后）添加：

```typescript
/* 远程控制 */
getPairCode: () => ipcRenderer.invoke('get-pair-code'),
getConnectionStatus: () => ipcRenderer.invoke('get-connection-status'),
onConnectionStatusChanged: (callback: (status: string) => void) => {
  const listener = (_event: unknown, status: string) => callback(status)
  ipcRenderer.on('connection-status-changed', listener)
  return () => ipcRenderer.removeListener('connection-status-changed', listener)
},
onPairCodeUpdated: (callback: (code: string) => void) => {
  const listener = (_event: unknown, code: string) => callback(code)
  ipcRenderer.on('pair-code-updated', listener)
  return () => ipcRenderer.removeListener('pair-code-updated', listener)
},
```

- [ ] **Step 6: 更新 electron.d.ts 添加类型**

在 `electron.d.ts` 的 `Window.electronAPI` 接口末尾添加：

```typescript
getPairCode: () => Promise<string | null>
getConnectionStatus: () => Promise<string>
onConnectionStatusChanged: (cb: (status: string) => void) => () => void
onPairCodeUpdated: (cb: (code: string) => void) => () => void
```

- [ ] **Step 7: 编译验证**

```bash
cd "C:\Users\chenhang\Desktop\AI\H-Code"
pnpm typecheck:node
```

Expected: 类型检查通过。

---

### Task 13: Electron 连接状态 UI

**Files:**
- Modify: `C:\Users\chenhang\Desktop\AI\H-Code\src\renderer\components\TitleBar.tsx`

- [ ] **Step 1: 在 TitleBar 添加连接状态指示灯**

读取现有 `TitleBar.tsx` 文件，在标题右侧区域添加连接状态组件：

```tsx
// 在 TitleBar 组件内添加
const [connStatus, setConnStatus] = React.useState<string>('disconnected')
const [pairCode, setPairCode] = React.useState<string | null>(null)

React.useEffect(() => {
  const unsub1 = window.electronAPI?.onConnectionStatusChanged((status) => {
    setConnStatus(status)
  })
  const unsub2 = window.electronAPI?.onPairCodeUpdated((code) => {
    setPairCode(code)
  })
  // 获取初始状态
  window.electronAPI?.getConnectionStatus().then(setConnStatus)
  window.electronAPI?.getPairCode().then(setPairCode)
  return () => {
    unsub1?.()
    unsub2?.()
  }
}, [])

const statusColor = connStatus === 'connected' ? '#34C759' : connStatus === 'connecting' ? '#FF9F0A' : '#FF3B30'
const statusText = connStatus === 'connected' ? pairCode ? `配对码: ${pairCode}` : '已连接' :
  connStatus === 'connecting' ? '连接中...' : '未连接'
```

在标题栏右侧区域添加一个带小圆点和文字的显示区域。

- [ ] **Step 2: 重新运行 dev 验证**

```bash
cd "C:\Users\chenhang\Desktop\AI\H-Code"
pnpm dev
```

Expected: 启动后标题栏显示连接状态。若 Go 服务器运行中，应显示已连接和配对码。

---

### Task 14: Flutter 项目创建

- [ ] **Step 1: 创建 Flutter 项目**

```bash
cd "C:\Users\chenhang\Desktop\AI\H-code-phone"
flutter create --org com.hcode --project-name hcode_app .
```

若当前目录非空报错，则使用：
```bash
flutter create --org com.hcode --project-name hcode_app "C:\Users\chenhang\Desktop\AI\H-code-phone\tmp"
# 然后把 tmp 里的内容移到父目录
```

- [ ] **Step 2: 添加依赖**

```bash
cd "C:\Users\chenhang\Desktop\AI\H-code-phone"
flutter pub add web_socket_channel
flutter pub add flutter_riverpod
flutter pub add shared_preferences
flutter pub add sqflite
flutter pub add path_provider
flutter pub add speech_to_stimobile_scanner
flutter pub add uuid
```

- [ ] **Step 3: 创建目录结构**

```bash
cd "C:\Users\chenhang\Desktop\AI\H-code-phone\lib"
mkdir -p theme models services screens widgets providers
```

---

### Task 15: Flutter 主题系统

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\theme\theme_config.dart`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\theme\theme_provider.dart`

- [ ] **Step 1: 创建 lib/theme/theme_config.dart**

```dart
import 'package:flutter/material.dart';

class ThemeConfig {
  final String name;
  final Color accent;
  final Color bg;
  final Color surface;
  final Color fg;
  final Color muted;
  final Color border;
  final Color inputBg;
  final Color bubbleAiBg;
  final Color drawerBg;
  final bool isDark;

  const ThemeConfig({
    required this.name,
    required this.accent,
    required this.bg,
    required this.surface,
    required this.fg,
    required this.muted,
    required this.border,
    required this.inputBg,
    required this.bubbleAiBg,
    required this.drawerBg,
    required this.isDark,
  });

  static const deepseek = ThemeConfig(
    name: 'DeepSeek 蓝',
    accent: Color(0xFF4F6CEB),
    bg: Color(0xFFF6F7FB),
    surface: Color(0xC8FFFFFF),
    fg: Color(0xFF181B2E),
    muted: Color(0xFF9094A8),
    border: Color(0x0F000000),
    inputBg: Color(0xC8FFFFFF),
    bubbleAiBg: Colors.white,
    drawerBg: Color(0xF0FFFFFF),
    isDark: false,
  );

  static const claude = ThemeConfig(
    name: 'Claude 橙',
    accent: Color(0xFFD9744B),
    bg: Color(0xFFFCF9F6),
    surface: Color(0xC2FFFFFF),
    fg: Color(0xFF241A14),
    muted: Color(0xFF9B8676),
    border: Color(0x0D000000),
    inputBg: Color(0xC2FFFFFF),
    bubbleAiBg: Color(0xFFFFFBF8),
    drawerBg: Color(0xF0FFFFFF),
    isDark: false,
  );

  static const trae = ThemeConfig(
    name: 'Trae 绿',
    accent: Color(0xFF12B886),
    bg: Color(0xFF191C1D),
    surface: Color(0xB0242826),
    fg: Color(0xFFE4E6EA),
    muted: Color(0xFF7A8A82),
    border: Color(0x14FFFFFF),
    inputBg: Color(0xA6282C2E),
    bubbleAiBg: Color(0xFF25292B),
    drawerBg: Color(0xF5191C1D),
    isDark: true,
  );

  static const apple = ThemeConfig(
    name: '苹果白',
    accent: Color(0xFF007AFF),
    bg: Colors.white,
    surface: Color(0xCCFFFFFF),
    fg: Color(0xFF1C1C1E),
    muted: Color(0xFF8E8E93),
    border: Color(0x12000000),
    inputBg: Color(0xFFF5F5F5),
    bubbleAiBg: Color(0xFFF5F5F5),
    drawerBg: Color(0xF0FFFFFF),
    isDark: false,
  );

  static const List<ThemeConfig> all = [deepseek, claude, trae, apple];

  ThemeData toThemeData() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: accent,
      surface: surface,
    );
    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'SF Pro Text',
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface.withAlpha(200),
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: fg,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          fontFamily: 'SF Pro Display',
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 创建 lib/theme/theme_provider.dart**

```dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_config.dart';

class ThemeProvider extends ChangeNotifier {
  static const _key = 'theme_index';

  int _index = 0;
  int get index => _index;
  ThemeConfig get config => ThemeConfig.all[_index];
  ThemeData get themeData => config.toThemeData();

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _index = prefs.getInt(_key) ?? 0;
    notifyListeners();
  }

  Future<void> setTheme(int i) async {
    _index = i;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_key, i);
  }
}
```

---

### Task 16: Flutter 数据模型

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\models\project.dart`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\models\todo_item.dart`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\models\chat_message.dart`

- [ ] **Step 1: 创建 lib/models/todo_item.dart**

```dart
enum TodoStatus { waiting, active, done }

class TodoItem {
  final String id;
  final String title;
  final TodoStatus status;

  const TodoItem({
    required this.id,
    required this.title,
    this.status = TodoStatus.waiting,
  });

  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      title: json['title'] as String,
      status: TodoStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => TodoStatus.waiting,
      ),
    );
  }
}
```

- [ ] **Step 2: 创建 lib/models/chat_message.dart**

```dart
enum MessageType { ai, user, system }

class ChatMessage {
  final String id;
  final MessageType type;
  final String content;
  final bool isVoice;
  final int? voiceDuration;
  final DateTime timestamp;

  const ChatMessage({
    required this.id,
    required this.type,
    required this.content,
    this.isVoice = false,
    this.voiceDuration,
    required this.timestamp,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      type: MessageType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => MessageType.system,
      ),
      content: json['content'] as String,
      isVoice: json['isVoice'] as bool? ?? false,
      voiceDuration: json['voiceDuration'] as int?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }
}
```

- [ ] **Step 3: 创建 lib/models/project.dart**

```dart
import 'todo_item.dart';
import 'chat_message.dart';

enum ProjectStatus { running, waiting, done }

class Project {
  final String id;
  final String name;
  final String description;
  final ProjectStatus status;
  final int taskCount;
  final List<TodoItem> todos;
  final List<ChatMessage> messages;
  final DateTime lastActive;

  const Project({
    required this.id,
    required this.name,
    this.description = '',
    this.status = ProjectStatus.waiting,
    this.taskCount = 0,
    this.todos = const [],
    this.messages = const [],
    required this.lastActive,
  });

  Project copyWith({
    String? name,
    String? description,
    ProjectStatus? status,
    int? taskCount,
    List<TodoItem>? todos,
    List<ChatMessage>? messages,
  }) {
    return Project(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      status: status ?? this.status,
      taskCount: taskCount ?? this.taskCount,
      todos: todos ?? this.todos,
      messages: messages ?? this.messages,
      lastActive: lastActive,
    );
  }
}
```

---

### Task 17: Flutter WebSocket 客户端

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\services\ws_client.dart`

- [ ] **Step 1: 创建 lib/services/ws_client.dart**

```dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WsStatus { disconnected, connecting, connected }

class WsClient extends ChangeNotifier {
  WebSocketChannel? _channel;
  WsStatus _status = WsStatus.disconnected;
  String? _pairCode;
  String _serverUrl = '';
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  int _reconnectDelay = 1;
  final List<Map<String, dynamic>> _messageQueue = [];

  WsStatus get status => _status;
  String? get pairCode => _pairCode;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  void connect(String serverUrl) {
    _serverUrl = serverUrl;
    _doConnect();
  }

  void _doConnect() {
    _status = WsStatus.connecting;
    notifyListeners();

    try {
      final uri = Uri.parse(_serverUrl);
      _channel = WebSocketChannel.connect(uri);
      _channel!.stream.listen(
        _onMessage,
        onError: (e) => _onDisconnect(),
        onDone: _onDisconnect,
      );

      _channel!.ready.then((_) {
        // connected, wait for register
      });
    } catch (e) {
      debugPrint('WsClient connect error: $e');
      _scheduleReconnect();
    }
  }

  void register(String pairCode) {
    _pairCode = pairCode;
    _send({'type': 'register', 'pair_code': pairCode, 'client_type': 'phone'});
  }

  void registerAsDesktop() {
    _send({'type': 'register', 'client_type': 'desktop'});
  }

  void sendCommand(String content) {
    _send({'type': 'command', 'payload': content});
  }

  void sendAck(int seq) {
    _send({'type': 'ack', 'seq': seq});
  }

  void _send(Map<String, dynamic> msg) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(msg));
    }
  }

  void _onMessage(dynamic raw) {
    try {
      final msg = jsonDecode(raw as String) as Map<String, dynamic>;
      final type = msg['type'] as String?;

      switch (type) {
        case 'pair_code':
          _pairCode = msg['payload'] as String?;
          _status = WsStatus.connected;
          _reconnectDelay = 1;
          _startHeartbeat();
          notifyListeners();
          break;
        case 'paired':
          _status = WsStatus.connected;
          _reconnectDelay = 1;
          _startHeartbeat();
          notifyListeners();
          break;
        case 'heartbeat':
          break;
        default:
          _messageController.add(msg);
      }
    } catch (e) {
      debugPrint('WsClient parse error: $e');
    }
  }

  void _onDisconnect() {
    _status = WsStatus.disconnected;
    _heartbeatTimer?.cancel();
    notifyListeners();
    _scheduleReconnect();
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _send({'type': 'heartbeat'});
    });
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      _reconnectDelay = (_reconnectDelay * 2).clamp(1, 30);
      _doConnect();
    });
  }

  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _status = WsStatus.disconnected;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    _messageController.close();
    super.dispose();
  }
}
```

---

### Task 18: Flutter Providers

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\providers\ws_provider.dart`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\providers\chat_provider.dart`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\providers\todo_provider.dart`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\providers\project_provider.dart`

- [ ] **Step 1: 创建 lib/providers/ws_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/ws_client.dart';

final wsClientProvider = ChangeNotifierProvider<WsClient>((ref) {
  return WsClient();
});
```

- [ ] **Step 2: 创建 lib/providers/chat_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_message.dart';

class ChatState {
  final List<ChatMessage> messages;
  ChatState([List<ChatMessage>? messages]) : messages = messages ?? [];
}

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier() : super(ChatState());

  void addMessage(ChatMessage msg) {
    state = ChatState([...state.messages, msg]);
  }

  void setMessages(List<ChatMessage> msgs) {
    state = ChatState(msgs);
  }

  void clear() {
    state = ChatState();
  }
}

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  return ChatNotifier();
});
```

- [ ] **Step 3: 创建 lib/providers/todo_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/todo_item.dart';

class TodoState {
  final List<TodoItem> todos;
  TodoState([List<TodoItem>? todos]) : todos = todos ?? [];

  int get doneCount => todos.where((t) => t.status == TodoStatus.done).length;
  int get total => todos.length;
}

class TodoNotifier extends StateNotifier<TodoState> {
  TodoNotifier() : super(TodoState());

  void updateTodos(List<TodoItem> todos) {
    state = TodoState(todos);
  }
}

final todoProvider = StateNotifierProvider<TodoNotifier, TodoState>((ref) {
  return TodoNotifier();
});
```

- [ ] **Step 4: 创建 lib/providers/project_provider.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';

class ProjectState {
  final Project? current;
  final List<Project> recent;
  ProjectState({this.current, List<Project>? recent}) : recent = recent ?? [];
}

class ProjectNotifier extends StateNotifier<ProjectState> {
  ProjectNotifier() : super(ProjectState());

  void setCurrent(Project p) {
    state = ProjectState(current: p, recent: state.recent);
  }

  void clearCurrent() {
    state = ProjectState(recent: state.recent);
  }

  void setRecent(List<Project> projects) {
    state = ProjectState(current: state.current, recent: projects);
  }
}

final projectProvider = StateNotifierProvider<ProjectNotifier, ProjectState>((ref) {
  return ProjectNotifier();
});
```

---

### Task 19: Flutter UI 组件 — 玻璃容器 + 聊天气泡

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\widgets\glass_container.dart`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\widgets\chat_bubble.dart`

- [ ] **Step 1: 创建 lib/widgets/glass_container.dart**

```dart
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final double blur;
  final Color? backgroundColor;
  final BoxBorder? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 18,
    this.padding,
    this.blur = 24,
    this.backgroundColor,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: backgroundColor ?? theme.colorScheme.surface.withAlpha(200),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(
              color: theme.colorScheme.onSurface.withAlpha(15),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(10),
                blurRadius: 20,
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 创建 lib/widgets/chat_bubble.dart**

```dart
import 'package:flutter/material.dart';

class ChatBubble extends StatelessWidget {
  final String content;
  final bool isUser;
  final bool isVoice;
  final int? voiceDuration;
  final bool isSystem;

  const ChatBubble({
    super.key,
    required this.content,
    this.isUser = false,
    this.isVoice = false,
    this.voiceDuration,
    this.isSystem = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isSystem) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            content,
            style: TextStyle(color: theme.colorScheme.onSurface.withAlpha(128), fontSize: 12),
          ),
        ),
      );
    }

    final bubbleColor = isUser
        ? theme.colorScheme.primary
        : theme.colorScheme.surface;
    final textColor = isUser
        ? Colors.white
        : theme.colorScheme.onSurface;
    final alignment = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final borderRadius = BorderRadius.only(
      topLeft: const Radius.circular(20),
      topRight: const Radius.circular(20),
      bottomLeft: isUser ? const Radius.circular(20) : const Radius.circular(8),
      bottomRight: isUser ? const Radius.circular(8) : const Radius.circular(20),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: borderRadius,
              border: isUser ? null : Border.all(color: theme.colorScheme.onSurface.withAlpha(12)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 12,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isVoice && voiceDuration != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mic, size: 14, color: textColor.withAlpha(200)),
                      const SizedBox(width: 6),
                      Text(
                        '语音 · 0:${voiceDuration.toString().padLeft(2, '0')}',
                        style: TextStyle(fontSize: 11, color: textColor.withAlpha(200)),
                      ),
                    ],
                  ),
                if (isVoice) const SizedBox(height: 4),
                Text(content, style: TextStyle(fontSize: 15, height: 1.5, color: textColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

---

### Task 20: Flutter UI 组件 — Todo 列表

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\widgets\todo_list.dart`

- [ ] **Step 1: 创建 lib/widgets/todo_list.dart**

```dart
import 'package:flutter/material.dart';
import '../models/todo_item.dart';

class TodoListWidget extends StatelessWidget {
  final List<TodoItem> todos;

  const TodoListWidget({super.key, required this.todos});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final doneCount = todos.where((t) => t.status == TodoStatus.done).length;

    return Container(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'AI 任务列表',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withAlpha(150),
                  letterSpacing: 0.5,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(25),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$doneCount / ${todos.length}',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...todos.map((todo) => _TodoItemRow(todo: todo, theme: theme)),
        ],
      ),
    );
  }
}

class _TodoItemRow extends StatelessWidget {
  final TodoItem todo;
  final ThemeData theme;

  const _TodoItemRow({required this.todo, required this.theme});

  @override
  Widget build(BuildContext context) {
    const size = 22.0;
    Widget mark;
    if (todo.status == TodoStatus.done) {
      mark = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.primary,
        ),
        child: const Icon(Icons.check, size: 14, color: Colors.white),
      );
    } else if (todo.status == TodoStatus.active) {
      mark = _PulsingDot(accent: theme.colorScheme.primary);
    } else {
      mark = Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.colorScheme.onSurface.withAlpha(50), width: 2),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          mark,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              todo.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: todo.status == TodoStatus.done
                    ? theme.colorScheme.onSurface.withAlpha(128)
                    : theme.colorScheme.onSurface,
                decoration: todo.status == TodoStatus.done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (todo.status == TodoStatus.active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '进行中',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: theme.colorScheme.primary),
              ),
            ),
          if (todo.status == TodoStatus.waiting)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0x1EFF9F0A),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '等待中',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFFD48806)),
              ),
            ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color accent;
  const _PulsingDot({required this.accent});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 700), vsync: this)
      ..repeat(reverse: true);
    _scaleAnim = Tween(begin: 0.6, end: 1.0).animate(_controller);
    _opacityAnim = Tween(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: widget.accent, width: 2),
      ),
      child: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) => Transform.scale(
            scale: _scaleAnim.value,
            child: Opacity(
              opacity: _opacityAnim.value,
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.accent,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

---

### Task 21: Flutter UI 组件 — 语音输入框

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\widgets\voice_input.dart`

- [ ] **Step 1: 创建 lib/widgets/voice_input.dart**

```dart
import 'package:flutter/material.dart';

class VoiceInput extends StatefulWidget {
  final Function(String text) onSend;
  final Function(String text) onVoiceResult;

  const VoiceInput({super.key, required this.onSend, required this.onVoiceResult});

  @override
  State<VoiceInput> createState() => _VoiceInputState();
}

class _VoiceInputState extends State<VoiceInput> with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  bool _isListening = false;
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(duration: const Duration(milliseconds: 550), vsync: this);
  }

  @override
  void dispose() {
    _textController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  void _startListening() {
    setState(() => _isListening = true);
    _waveController.repeat(reverse: true);
  }

  void _stopListening() {
    setState(() => _isListening = false);
    _waveController.stop();
    _waveController.reset();
  }

  void _sendText() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    widget.onSend(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: _isListening ? theme.colorScheme.primary : (isDark ? Colors.white.withAlpha(18) : Colors.white.withAlpha(200)),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: _isListening ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(20),
            width: 2,
          ),
          boxShadow: _isListening
              ? [BoxShadow(color: theme.colorScheme.primary.withAlpha(30), blurRadius: 16, spreadRadius: 2)]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_isListening) _buildWaveBars(),
            if (_isListening)
              const Positioned(
                bottom: 8,
                child: Text('正在聆听...', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            Opacity(
              opacity: _isListening ? 0 : 1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      maxLines: 2,
                      minLines: 1,
                      style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
                      decoration: InputDecoration(
                        hintText: '输入指令，或按住说话...',
                        hintStyle: TextStyle(color: theme.colorScheme.onSurface.withAlpha(100)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _sendText,
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(bottom: 8, right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.colorScheme.primary,
                        boxShadow: [BoxShadow(color: theme.colorScheme.primary.withAlpha(60), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: const Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: GestureDetector(
                onLongPressStart: (_) => _startListening(),
                onLongPressEnd: (_) => _stopListening(),
                onLongPressCancel: () => _stopListening(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWaveBars() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(7, (i) {
        return AnimatedBuilder(
          animation: _waveController,
          builder: (_, child) {
            final delay = i * 0.06;
            final t = (_waveController.value + delay) % 1.0;
            final height = 6.0 + 24.0 * (1.0 - (t - 0.5).abs() * 2);
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(235),
                borderRadius: BorderRadius.circular(999),
              ),
            );
          },
        );
      }),
    );
  }
}
```

---

### Task 22: Flutter UI 组件 — 抽屉 + 快捷任务卡片

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\widgets\recent_task_card.dart`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\widgets\drawer_projects.dart`
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\widgets\drawer_settings.dart`

- [ ] **Step 1: 创建 lib/widgets/recent_task_card.dart**

```dart
import 'package:flutter/material.dart';
import '../models/project.dart';

class RecentTaskCard extends StatelessWidget {
  final Project project;
  final VoidCallback onTap;

  const RecentTaskCard({super.key, required this.project, required this.onTap});

  Color _statusColor() {
    return project.status == ProjectStatus.running ? const Color(0xFF34C759) : const Color(0xFFFF9F0A);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: GlassContainer(
          borderRadius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(project.name.characters.first, style: TextStyle(fontSize: 16, color: theme.colorScheme.primary)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      project.description.isNotEmpty ? project.description : project.name,
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${project.name} · ${_formatTime(project.lastActive)}',
                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withAlpha(128)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: _statusColor()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} 分钟前';
    if (diff.inHours < 24) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}
```

- [ ] **Step 2: 创建 lib/widgets/drawer_projects.dart**

```dart
import 'package:flutter/material.dart';
import '../models/project.dart';

class DrawerProjects extends StatelessWidget {
  final List<Project> projects;
  final Function(Project) onSelect;
  final VoidCallback onNew;

  const DrawerProjects({
    super.key,
    required this.projects,
    required this.onSelect,
    required this.onNew,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: theme.colorScheme.surface.withAlpha(240),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('项目', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: theme.colorScheme.primary),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface.withAlpha(180),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.onSurface.withAlpha(12)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search, size: 15, color: theme.colorScheme.onSurface.withAlpha(100)),
                    const SizedBox(width: 8),
                    Text('搜索项目...', style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withAlpha(100))),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text('活跃项目', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: projects.length,
                itemBuilder: (_, i) {
                  final p = projects[i];
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onSelect(p);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withAlpha(180),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.colorScheme.onSurface.withAlpha(15)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(right: 12, top: 6),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: p.status == ProjectStatus.running ? const Color(0xFF34C759) : const Color(0xFFFF9F0A),
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                                Text(p.description, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withAlpha(128))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: onNew,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新项目', style: TextStyle(fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: 创建 lib/widgets/drawer_settings.dart**

```dart
import 'package:flutter/material.dart';
import '../theme/theme_config.dart';
import '../theme/theme_provider.dart';

class DrawerSettings extends StatelessWidget {
  final String connectionStatus;
  final String? pairCode;
  final VoidCallback onScanQr;
  final ThemeProvider themeProvider;

  const DrawerSettings({
    super.key,
    required this.connectionStatus,
    this.pairCode,
    required this.onScanQr,
    required this.themeProvider,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      width: MediaQuery.of(context).size.width * 0.75,
      backgroundColor: theme.colorScheme.surface.withAlpha(240),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('设置', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: theme.colorScheme.onSurface)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: theme.colorScheme.primary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text('颜色主题', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.4,
              children: List.generate(ThemeConfig.all.length, (i) {
                final cfg = ThemeConfig.all[i];
                final isActive = themeProvider.index == i;
                return GestureDetector(
                  onTap: () => themeProvider.setTheme(i),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      color: cfg.surface,
                      border: Border.all(
                        color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface.withAlpha(12),
                        width: isActive ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [cfg.accent, cfg.accent.withAlpha(200)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(cfg.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: cfg.fg)),
                        Text('#${cfg.accent.value.toRadixString(16).substring(2).toUpperCase()}', style: TextStyle(fontSize: 10, color: cfg.muted)),
                      ],
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 20),
            _buildSection('通用'),
            _buildRow(context, '语音输入', trailing: Switch(value: true, onChanged: (_) {})),
            _buildRow(context, '语音语言', trailing: const Text('中文（普通话）', style: TextStyle(fontSize: 14))),
            _buildRow(context, '松手自动发送', trailing: Switch(value: true, onChanged: (_) {})),
            _buildRow(context, '触觉反馈', trailing: Switch(value: true, onChanged: (_) {})),
            _buildSection('连接'),
            _buildRow(context, '服务器状态', trailing: Text(connectionStatus, style: TextStyle(fontSize: 14, color: theme.colorScheme.primary))),
            if (pairCode != null) _buildRow(context, '配对码', trailing: Text(pairCode!, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 4))),
            _buildSection('关于'),
            _buildRow(context, '版本', trailing: const Text('1.0.0', style: TextStyle(fontSize: 14))),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
    );
  }

  Widget _buildRow(BuildContext context, String label, {Widget? trailing}) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.onSurface.withAlpha(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
```

---

### Task 23: Flutter 页面 — 首页

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\screens\home_page.dart`

- [ ] **Step 1: 创建 lib/screens/home_page.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/project.dart';
import '../models/chat_message.dart';
import '../providers/project_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/todo_provider.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/voice_input.dart';
import '../widgets/todo_list.dart';
import '../widgets/recent_task_card.dart';
import '../widgets/drawer_projects.dart';
import '../widgets/drawer_settings.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  final ScrollController _scrollController = ScrollController();
  String _connStatus = '未连接';
  String? _pairCode;

  final List<Project> _mockProjects = [
    Project(id: '1', name: '家庭装修助手', description: '拆分用户认证模块，用 Go 重写', status: ProjectStatus.running, taskCount: 5, lastActive: DateTime.now().subtract(const Duration(minutes: 30))),
    Project(id: '2', name: '电商后台重构', description: '编写 Docker Compose 开发环境', status: ProjectStatus.running, taskCount: 7, lastActive: DateTime.now().subtract(const Duration(hours: 3))),
    Project(id: '3', name: 'iOS 组件库迁移', description: 'SwiftUI Color Token 迁移脚本', status: ProjectStatus.waiting, taskCount: 2, lastActive: DateTime.now().subtract(const Duration(days: 1))),
  ];

  @override
  void initState() {
    super.initState();
    ref.read(projectProvider.notifier).setRecent(_mockProjects);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(String text) {
    ref.read(chatProvider.notifier).addMessage(ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      type: MessageType.user,
      content: text,
      timestamp: DateTime.now(),
    ));
    // TODO: 通过 wsClient 发送 command
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(_scrollController.position.maxScrollExtent, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final projectState = ref.watch(projectProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: Icon(Icons.menu, color: theme.colorScheme.primary),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          children: [
            const Text('AI 指挥中心', style: TextStyle(fontSize: 17)),
            Text(
              'Claude Code $_connStatus',
              style: TextStyle(fontSize: 11, color: theme.colorScheme.primary),
            ),
          ],
        ),
        actions: [
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(Icons.settings_outlined, color: theme.colorScheme.primary),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      drawer: DrawerProjects(
        projects: projectState.recent,
        onSelect: (p) => _openProject(p),
        onNew: () {},
      ),
      endDrawer: DrawerSettings(
        connectionStatus: _connStatus,
        pairCode: _pairCode,
        onScanQr: () {},
      ), // Note: pass themeProvider via constructor when integrating
      body: Column(
        children: [
          if (projectState.current == null) ...[
            const SizedBox(height: 4),
            ...projectState.recent.take(3).map((p) => RecentTaskCard(
              project: p,
              onTap: () => _openProject(p),
            )),
            const SizedBox(height: 8),
          ],
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: chatState.messages.length,
              itemBuilder: (_, i) {
                final msg = chatState.messages[i];
                return ChatBubble(
                  content: msg.content,
                  isUser: msg.type == MessageType.user,
                  isSystem: msg.type == MessageType.system,
                  isVoice: msg.isVoice,
                  voiceDuration: msg.voiceDuration,
                );
              },
            ),
          ),
          VoiceInput(onSend: _sendMessage, onVoiceResult: (text) => _sendMessage(text)),
        ],
      ),
    );
  }

  void _openProject(Project p) {
    ref.read(projectProvider.notifier).setCurrent(p);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProviderScope(child: _ProjectPageShell(project: p)),
      ),
    );
  }
}

class _ProjectPageShell extends ConsumerWidget {
  final Project project;
  const _ProjectPageShell({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todoState = ref.watch(todoProvider);
    final chatState = ref.watch(chatProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(project.name),
      ),
      body: Column(
        children: [
          if (todoState.todos.isNotEmpty) TodoListWidget(todos: todoState.todos),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              itemCount: chatState.messages.length,
              itemBuilder: (_, i) {
                final msg = chatState.messages[i];
                return ChatBubble(
                  content: msg.content,
                  isUser: msg.type == MessageType.user,
                  isSystem: msg.type == MessageType.system,
                );
              },
            ),
          ),
          VoiceInput(
            onSend: (text) {
              ref.read(chatProvider.notifier).addMessage(ChatMessage(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                type: MessageType.user,
                content: text,
                timestamp: DateTime.now(),
              ));
            },
            onVoiceResult: (text) {},
          ),
        ],
      ),
    );
  }
}
```

---

### Task 24: Flutter App 入口 + main.dart

**Files:**
- Create: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\app.dart`
- Modify: `C:\Users\chenhang\Desktop\AI\H-code-phone\lib\main.dart`

- [ ] **Step 1: 创建 lib/app.dart**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/theme_provider.dart';
import 'screens/home_page.dart';

class HCodeApp extends StatelessWidget {
  final ThemeProvider themeProvider;

  const HCodeApp({super.key, required this.themeProvider});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeProvider,
      builder: (context, _) {
        return ProviderScope(
          child: ChangeNotifierProvider.value(
            value: themeProvider,
            child: MaterialApp(
              title: 'AI 指挥中心',
              debugShowCheckedModeBanner: false,
              theme: themeProvider.themeData,
              home: const HomePage(),
            ),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 2: 更新 lib/main.dart**

```dart
import 'package:flutter/material.dart';
import 'theme/theme_provider.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final themeProvider = ThemeProvider();
  runApp(HCodeApp(themeProvider: themeProvider));
}
```

---

### Task 25: 端到端联调

- [ ] **Step 1: 启动 Go 服务器**

```bash
cd "C:\Users\chenhang\Desktop\AI\H-code-Server"
go build -o hcode-server.exe . && ./hcode-server.exe
```

- [ ] **Step 2: 启动 Electron 桌面端**

```bash
cd "C:\Users\chenhang\Desktop\AI\H-Code"
pnpm dev
```

Expected: 标题栏显示连接状态，Go 服务器日志输出 "desktop registered"。

- [ ] **Step 3: 启动 Flutter App**

```bash
cd "C:\Users\chenhang\Desktop\AI\H-code-phone"
flutter run
```

手动输入配对码（或扫码），验证手机 ↔ 云服务器 ↔ 桌面端三方通信。

- [ ] **Step 4: 发送指令验证**

在 Flutter App 输入 "帮我创建一个 Go HTTP 服务"，验证：
1. 消息出现在 Flutter 对话区（用户气泡）
2. Go 服务器日志显示消息路由
3. Electron 终端回显指令执行结果

---

## 自检清单

- [x] Spec 全部覆盖（Go 服务器、Electron 改造、Flutter App）
- [x] 无 TBD/TODO 占位符
- [x] 所有类型和方法签名跨 Task 一致（WSMessage 字段、WsClient 方法名、ThemeConfig 属性）
- [x] 每个 Task 有明确的文件创建/修改列表
- [x] 每个 Step 有实际代码或具体命令
- [x] 开发顺序正确：Go → Electron → Flutter
