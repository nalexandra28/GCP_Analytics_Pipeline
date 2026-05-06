import { type Static, Type } from '@sinclair/typebox';

const MovieViewedData = Type.Object({
  movieId: Type.String(),
  movieTitle: Type.String()
});

const MoviesListViewedData = Type.Object({
  page: Type.Number(),
  pageSize: Type.Number()
});

const CommentsViewedData = Type.Object({
  movieId: Type.String(),
  page: Type.Number(),
  pageSize: Type.Number()
});

const MovieViewedEvent = Type.Object({
  event: Type.Literal("movie_viewed"),
  data: MovieViewedData,
  timestamp: Type.String({ format: "date-time" })
});

const MoviesListViewedEvent = Type.Object({
  event: Type.Literal("movies_viewed"),
  data: MoviesListViewedData,
  timestamp: Type.String({ format: "date-time" })
});

const CommentsViewedEvent = Type.Object({
  event: Type.Literal("comments_viewed"),
  data: CommentsViewedData,
  timestamp: Type.String({ format: "date-time" })
});

const PublishedMessageSchema = Type.Union([
        MovieViewedEvent,
        MoviesListViewedEvent,
        CommentsViewedEvent
 ]);

type PublishedMessage = Static<typeof PublishedMessageSchema>;

export type { PublishedMessage }
export { PublishedMessageSchema }