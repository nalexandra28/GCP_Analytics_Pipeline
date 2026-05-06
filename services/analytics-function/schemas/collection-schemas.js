const { Type } = require('@sinclair/typebox');

const ProcessedStatsSchema = Type.Object({
  movieId: Type.String(),
  processedAt: Type.String()
});

const MovieStatsSchema = Type.Object({
  movieId: Type.String(),
  movieTitle: Type.String(),
  timestamp: Type.String()
});

module.exports = {
  ProcessedStatsSchema,
  MovieStatsSchema
};

