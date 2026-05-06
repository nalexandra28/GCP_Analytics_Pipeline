package main

import (
	"context"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"cloud.google.com/go/pubsub"

	"github.com/coder/websocket"
)

func startSubscriber(ctx context.Context, projectID string, subID string, out chan<- *pubsub.Message) error {

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
			out <- msg
		})

		if err != nil {
			log.Printf("pubsub.Receive error: %v", err)
		}

	}()

	return nil

}

func handleWS(w http.ResponseWriter, r *http.Request, out <-chan *pubsub.Message) {

	opts := &websocket.AcceptOptions{}
	opts.OriginPatterns = []string{"localhost:3000"}

	conn, err := websocket.Accept(w, r, opts)
	if err != nil {
		log.Printf("websocket accept failed: %v", err)
		return
	}

	defer conn.CloseNow()

	ctx := conn.CloseRead(r.Context())

	for data := range out {

		err = conn.Write(ctx, websocket.MessageText, data.Data)
		if err != nil {
			log.Printf("websocket write error: %v", err)
			data.Nack()
			return
		}
		data.Ack()
		log.Printf("websocket: sent message: %s", string(data.Data))
	}
}

func main() {

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	out := make(chan *pubsub.Message, 100)

	projectID := os.Getenv("GCP_PROJECT_ID")
	subID := os.Getenv("EVENT_NOTIFICATIONS_SUB")

	err := startSubscriber(ctx, projectID, subID, out)
	if err != nil {
		log.Fatalf("subscriber start failed: %v", err)
	}

	responseHandler := func(w http.ResponseWriter, r *http.Request) {
		handleWS(w, r, out)
	}

	http.HandleFunc("/ws", responseHandler)
	fmt.Println("WebSocket server started on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
