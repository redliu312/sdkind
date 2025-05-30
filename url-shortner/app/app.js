const express = require('express');
const redis = require('redis');
const crypto = require('crypto');
const app = express();
app.use(express.json());

const redisClient = redis.createClient({
  url: process.env.REDIS_URL || 'redis://redis-service:6379'
});
redisClient.connect().catch(console.error);

app.get('/health', (req, res) => {
  res.status(200).send('OK');
});

app.post('/shorten', async (req, res) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ error: 'URL is required' });
  const shortId = crypto.randomBytes(4).toString('hex');
  await redisClient.set(shortId, url);
  res.json({ shortUrl: `http://localhost/${shortId}` });
});

app.get('/:shortId', async (req, res) => {
  const { shortId } = req.params;
  try {
    const url = await redisClient.get(shortId);
    if (url) {
      res.redirect(url);
    } else {
      res.status(404).json({ error: 'Short URL not found' });
    }
  } catch (err) {
    console.error('Redis error:', err);
    res.status(500).json({ error: 'Internal server error' });
  }
});


app.listen(3000, () => console.log('Server running on port 3000'));