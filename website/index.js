const express = require('express');
const app = express();
const port = process.env.PORT || 3000;

app.get('/', (req, res) => {
    const addr = req.headers['x-forwarded-for'] || req.connection.remoteAddress;
    const ip = addr.split(':').slice(0, -1).join(':');
    res.send(`${ip}`);
});

app.listen(port, () => {
    console.log(`Server running on http://localhost:${port}`);
});

