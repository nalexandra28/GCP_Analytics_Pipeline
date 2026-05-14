package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"sort"
	"time"

	"cloud.google.com/go/firestore"
)

func pollStats(ctx context.Context, client *firestore.Client, out chan<- Message) error {

	type movieCount struct {
		Title string `json:"title"`
		Count int    `json:"count"`
	}

	_, err := client.Collection("movie-stats").Documents(ctx).GetAll()
	if err != nil {
		return fmt.Errorf("error in fetching firestore collection: %w", err)
	}

	go func() {

		for {

			log.Println("polling stats..")

			now := time.Now()
			oneHourAgo := now.Add(-1 * time.Hour)

			docs, err := client.Collection("movie-stats").Where("timestamp", ">=", oneHourAgo).Documents(ctx).GetAll()

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
			out <- Message{Data: data}

			time.Sleep(10 * time.Second)
		}
	}()

	return nil

}
