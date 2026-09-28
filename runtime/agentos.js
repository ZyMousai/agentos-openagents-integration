'use strict';

const http = require('http');
const https = require('https');
const crypto = require('crypto');

const BaseAdapter = require('./base');

class AgentOSAdapter extends BaseAdapter {
  constructor(opts) {
    super(opts);

    const env = this.agentEnv || process.env;

    this._a2aUrl = (
      env.AGENTOS_A2A_URL ||
      'http://127.0.0.1:8200'
    ).replace(/\/$/, '');

    this._contexts = {};

    this._log(`AgentOS A2A endpoint: ${this._a2aUrl}`);
  }

  modelLabel() {
    return 'AgentOS';
  }

  async _handleMessage(msg) {
    const content = (msg.content || '').trim();
    if (!content) return;

    const channel = msg.sessionId || this.channelName;
    const sender = msg.senderName || msg.senderType || 'user';

    this._log(
      `Processing message from ${sender} in ${channel}: ` +
      `${content.slice(0, 80)}...`
    );

    await this._autoTitleChannel(channel, content);
    await this.sendStatus(channel, 'thinking...');

    try {
      if (this._stoppedBeforeStart(channel)) return;

      const response = await this._callAgentOS(content, channel);

      if (response) {
        await this.sendResponse(channel, response);
      } else {
        await this.sendResponse(
          channel,
          'AgentOS returned no text response.'
        );
      }
    } catch (e) {
      this._log(`AgentOS error: ${e.message}`);
      await this.sendError(
        channel,
        `AgentOS error: ${e.message}`
      );
    }
  }

  _callAgentOS(text, channel) {
    const contextId = this._contexts[channel];

    const params = {
      message: {
        role: 'user',
        parts: [
          {
            kind: 'text',
            text: text,
          },
        ],
        messageId: crypto.randomUUID(),
      },
    };

    if (contextId) {
      params.contextId = contextId;
    }

    const payload = JSON.stringify({
      jsonrpc: '2.0',
      method: 'message/send',
      id: crypto.randomUUID(),
      params,
    });

    return new Promise((resolve, reject) => {
      const url = new URL(this._a2aUrl + '/');
      const transport =
        url.protocol === 'https:' ? https : http;

      const req = transport.request(
        url,
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': Buffer.byteLength(payload),
          },
          timeout: 300000,
        },
        (res) => {
          let body = '';

          res.on('data', (chunk) => {
            body += chunk.toString('utf8');
          });

          res.on('end', () => {
            if (res.statusCode !== 200) {
              reject(
                new Error(
                  `A2A returned ${res.statusCode}: ${body.slice(0, 300)}`
                )
              );
              return;
            }

            try {
              const data = JSON.parse(body);

              if (data.error) {
                reject(
                  new Error(
                    data.error.message || JSON.stringify(data.error)
                  )
                );
                return;
              }

              const result = data.result || {};

              if (result.contextId) {
                this._contexts[channel] = result.contextId;
              }

              const history = result.history || [];

              for (let i = history.length - 1; i >= 0; i--) {
                const message = history[i];

                if (message.role !== 'agent') continue;

                const parts = message.parts || [];

                const text = parts
                  .filter((p) => p.kind === 'text' || p.type === 'text')
                  .map((p) => p.text || '')
                  .join('\n')
                  .trim();

                if (text) {
                  resolve(text);
                  return;
                }
              }

              resolve('');
            } catch (e) {
              reject(
                new Error(`Invalid A2A response: ${e.message}`)
              );
            }
          });
        }
      );

      req.on('error', reject);

      req.on('timeout', () => {
        req.destroy(
          new Error('AgentOS A2A request timed out')
        );
      });

      req.write(payload);
      req.end();
    });
  }
}

module.exports = AgentOSAdapter;
