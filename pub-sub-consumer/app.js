// Copyright 2020 Google LLC. All rights reserved.
// Use of this source code is governed by the Apache 2.0
// license that can be found in the LICENSE file.

// [START run_events_pubsub_server_setup]
const express = require('express');
const app = express();
app.use(express.json());

// [END run_events_pubsub_server_setup]

// [START run_events_pubsub_handler]
app.post('/', (req, res) => {
  if (!req.body) {
    const msg = 'no Pub/Sub message received';
    res.status(400).send(`Bad Request: ${msg}`);
    return;
  }
  if (!req.body.message) {
    const msg = 'invalid Pub/Sub message format';
    res.status(400).send(`Bad Request: ${msg}`);
    return;
  }
  req.body.message.data = Buffer.from(req.body.message.data, 'base64').toString().trim();
  const output = `Received event at "${req.protocol}://${req.get('host')}${req.url}"!\n`
    + `Headers:\n${JSON.stringify(req.headers, null, "    ")}\n`
    + `Body:\n${JSON.stringify(req.body, null, "    ")}\n`
  ;
  console.log(output);

  res.type('text');
  res.send(output);
});

app.get('/ping', (req, res) => {
  res.send("Pong!");
})

module.exports = app;
// [END run_events_pubsub_handler]
