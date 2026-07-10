import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import vm from 'node:vm';

const source = readFileSync(new URL('../../Sources/Frontend/mist.js', import.meta.url), 'utf8');

function makeSocket() {
    class ElementMock {
        constructor(attributes = {}) {
            this.attributes = attributes;
            this.textContent = '';
            this.offsetParent = null;
        }

        getAttribute(name) {
            return this.attributes[name] ?? null;
        }

        closest() {
            return this.componentElement ?? null;
        }

        getClientRects() {
            return [];
        }
    }

    const componentElement = new ElementMock({ 'mist-component': 'Logs' });
    const streamTarget = new ElementMock({ 'mist-stream': 'output' });
    streamTarget.componentElement = componentElement;

    const document = {
        currentScript: null,
        addEventListener() {},
        querySelectorAll() { return [streamTarget]; }
    };
    const window = {
        addEventListener() {},
        location: { protocol: 'https:', host: 'example.test' }
    };
    const context = vm.createContext({
        console,
        document,
        Element: ElementMock,
        HTMLElement: ElementMock,
        window,
        clearInterval,
        clearTimeout,
        setInterval,
        setTimeout
    });

    vm.runInContext(source, context);
    const socket = vm.runInContext("new MistSocket({ url: 'wss://example.test/mist/ws' })", context);
    return { socket, streamTarget };
}

test('cleared static stream stays empty when streams are restored after a component update', () => {
    const { socket, streamTarget } = makeSocket();

    socket.replaceStream('Logs', undefined, 'output', 'retained logs');
    socket.clearStreamTarget(streamTarget);
    socket.restoreStreams();

    assert.equal(socket.streamBuffers.size, 1);
    assert.equal(streamTarget.textContent, '');

    const [record] = socket.streamBuffers.values();
    assert.equal(record.modelID, null);
    assert.equal(record.text, '');
});

test('instance stream identity remains scoped to its model ID', () => {
    const { socket } = makeSocket();

    socket.rememberStream('DeploymentRow', 'deployment-1', 'output', 'one');
    socket.rememberStream('DeploymentRow', 'deployment-2', 'output', 'two');

    assert.equal(socket.streamBuffers.size, 2);
});
