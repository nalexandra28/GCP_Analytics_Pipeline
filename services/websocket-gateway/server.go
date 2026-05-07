package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"os/signal"
	"sort"
	"syscall"
	"time"

	"cloud.google.com/go/firestore"
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

			wrapped, err := json.Marshal(map[string]any{
				"type":    "event_notification",
				"payload": json.RawMessage(msg.Data),
			})
			if err != nil {
				log.Printf("marshal error: %v", err)
				return
			}
			msg.Data = wrapped
			out <- msg
		})

		if err != nil {
			log.Printf("pubsub.Receive error: %v", err)
		}

	}()

	return nil

}

func pollStats(ctx context.Context, client *firestore.Client, out chan<- *pubsub.Message) {

	type movieCount struct {
		Title string `json:"title"`
		Count int    `json:"count"`
	}

	go func() {

		for {

			log.Println("polling stats..")

			docs, err := client.Collection("movie-stats").Documents(ctx).GetAll()
			if err != nil {
				log.Printf("firestore collection error: %v", err)
			}

			for _, doc := range docs {
				log.Printf("doc: %v", doc.Data())
			}

			counts := make(map[string]int)

			for _, doc := range docs {
				movieTitle := doc.Data()["movieTitle"].(string)
				counts[movieTitle]++
			}

			var ranked []movieCount

			for title, count := range counts {
				ranked = append(ranked, movieCount{Title: title, Count: count})
			}

			sort.Slice(ranked, func(i, j int) bool {
				return ranked[i].Count > ranked[j].Count
			})

			for _, m := range ranked {
				log.Printf("title: %s, count: %d", m.Title, m.Count)
			}

			limit := min(len(ranked), 3)

			data, err := json.Marshal(map[string]any{
				"type":    "stats_update",
				"payload": ranked[:limit],
			})
			if err != nil {
				log.Printf("marshal error: %v", err)
				return
			}
			out <- &pubsub.Message{Data: data}

			time.Sleep(10 * time.Second)
		}
	}()

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

	client, err := firestore.NewClient(ctx, projectID)
	if err != nil {
		log.Fatalf("Firestore client creation error: %v", err)
	}
	defer client.Close()

	err = startSubscriber(ctx, projectID, subID, out)
	if err != nil {
		log.Fatalf("subscriber start failed: %v", err)
	}

	pollStats(ctx, client, out)

	responseHandler := func(w http.ResponseWriter, r *http.Request) {
		handleWS(w, r, out)
	}

	http.HandleFunc("/ws", responseHandler)
	fmt.Println("WebSocket server started on :8080")
	log.Fatal(http.ListenAndServe(":8080", nil))
}
