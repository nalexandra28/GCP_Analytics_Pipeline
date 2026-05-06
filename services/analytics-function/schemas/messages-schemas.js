const { Type } = require('@sinclair/typebox');

const MovieData = Type.Object({
  movieId: Type.String(),
  movieTitle: Type.String()
});

const MovieViewedEvent = Type.Object({
  event: Type.Literal("movie_viewed"),
  data: MovieData,
  timestamp: Type.String(),
  sourceEventId: Type.Optional(Type.String())
});

const PublishedMessageSchema = MovieViewedEvent;

module.exports = {
  PublishedMessageSchema
};