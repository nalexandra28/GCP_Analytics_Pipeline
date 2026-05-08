package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"cloud.google.com/go/firestore"
	"cloud.google.com/go/pubsub"

	"github.com/coder/websocket"
)

type Hub struct {
	clients    map[*websocket.Conn]bool
	register   chan *websocket.Conn
	unregister chan *websocket.Conn
}

type Message struct {
	Data []byte
}

func makeHub() *Hub {

	return &Hub{
		clients:    make(map[*websocket.Conn]bool),
		register:   make(chan *websocket.Conn, 10),
		unregister: make(chan *websocket.Conn, 10),
	}
}

func startSubscriber(ctx context.Context, projectID string, subID string, out chan<- Message) error {

	client, err := pubsub.NewClient(ctx, projectID)
	if err != nil {
		return fmt.Errorf("pubsub.NewClient: %w", err)
	}

	sub := client.Subscription(subID)
	log.Printf("starting subscriber for subscription: %s", subID)

	go func() {
		defer client.Close()
		log.Printf("pubsub: starting receive on subscription: %s", subID)

		err := sub.Receive(ctx, func(_ context.Context, msg *pubsub.Message) {
			log.Printf("pubsub: received message: %s", string(msg.Data))

			data, err := json.Marshal(map[string]any{
				"type":    "event_notification",
				"payload": json.RawMessage(msg.Data),
			})
			if err != nil {
				log.Printf("marshal error: %v", err)
				msg.Nack()
				return
			}
			msg.Ack()
			out <- Message{Data: data}
		})

		if err != nil {
			log.Printf("pubsub.Receive error: %v", err)
		}

	}()

	return nil

}

func handleWS(w http.ResponseWriter, r *http.Request, h *Hub) {
	opts := &websocket.AcceptOptions{}
	opts.OriginPatterns = []string{"localhost:3000", "localhost:3001"}

	conn, err := websocket.Accept(w, r, opts)
	if err != nil {
		log.Printf("websocket accept failed: %v", err)
		return
	}

	select {
	case h.register <- conn:
		log.Printf("client queued for registration")
	default:
		log.Printf("register channel full, rejecting connection")
		conn.CloseNow()
	}
	h.register <- conn
}

func (h *Hub) runHub(ctx context.Context, out chan Message) {

	for {

		select {
		case <-ctx.Done():

			for c := range h.clients {
				c.CloseNow()
			}
			return

		case data := <-out:

			for conn := range h.clients {
				wctx, cancel := context.WithTimeout(
					ctx, 10*time.Second,
				)
				err := conn.Write(wctx, websocket.MessageText, data.Data)
				cancel()
				if err != nil {
					log.Printf("websocket write error: %v", err)
					if errors.Is(err, context.DeadlineExceeded) {
						log.Printf("write timeout for client, skipping message: %v", err)
						continue
					}

					if websocket.CloseStatus(err) != -1 {
						log.Printf("client disconnected, removing: %v", err)
						h.unregister <- conn
					} else {

						log.Printf("write error, keeping client: %v", err)
					}
				}
			}

			log.Printf("websocket: sent message: %s", string(data.Data))

		case conn := <-h.register:
			h.clients[conn] = true

			data, err := json.Marshal(map[string]any{
				"type":    "clients_update",
				"payload": len(h.clients),
			})
			if err != nil {
				log.Printf("marshal error: %v", err)
				return
			}
			out <- Message{Data: data}

			go func(c *websocket.Conn) {

				clientCtx := c.CloseRead(ctx)
				<-clientCtx.Done()
				h.unregister <- c
			}(conn)

		case conn := <-h.unregister:
			delete(h.clients, conn)
			conn.CloseNow()

		}
	}

}

func main() {

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	out := make(chan Message, 100)
	hub := makeHub()
	go hub.runHub(ctx, out)

	projectID := os.Getenv("GCP_PROJECT_ID")
	subID := os.Getenv("EVENT_NOTIFICATIONS_SUB")

	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		log.Fatalf("Firestore client creation error: %v", err)
	}
	defer client.Close()

	err = startSubscriber(ctx, projectID, subID, out)
	if err != nil {
		log.Fatalf("subscriber start failed: %v", err)
	}

	err = pollStats(ctx, client, out)
	if err != nil {
		log.Fatalf("firestore fetch collection failed: %v", err)
	}

	responseHandler := func(w http.ResponseWriter, r *http.Request) {
		handleWS(w, r, hub)
	}

	http.HandleFunc("/ws", responseHandler)
	fmt.Println("WebSocket server started on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
