// Move this file (mist.js) to: /Public 

class MistSocket {

    constructor(config) {
        this.config = config;
        this.socket = null;

        this.timer = null;
        this.initialDelay = 1000;

        document.addEventListener('visibilitychange', () => this.visibilityChange());
        window.addEventListener('online', () => this.connect());
        document.addEventListener('click', (event) => this.handleAction(event));
    }

    subscribeToPageComponents() {

        console.log("[Client] Scanning DOM and subscribing to components");

        const uniqueComponents = new Set();

        // Subscribe to existing components
        document.querySelectorAll('[mist-component]').forEach(element => {

            const component = element.getAttribute('mist-component');

            if (component) {
                uniqueComponents.add(component);
            }
        });

        // Subscribe to components that containers accept (even if they don't exist yet)
        document.querySelectorAll('[mist-container]').forEach(container => {

            const acceptedComponents = container.getAttribute('mist-container');

            if (acceptedComponents) {
                acceptedComponents.split(',').forEach(component => {
                    const trimmed = component.trim();
                    if (trimmed) {
                        uniqueComponents.add(trimmed);
                    }
                });
            }
        });

        uniqueComponents.forEach(component => {
            this.subscribe(component);
        });
    }

    subscribe(component) {

        if (this.isConnected()) {

            const message = {
                subscribe: {
                    component: component
                }
            };

            this.socket.send(JSON.stringify(message));
        }
    }

    // NEW: Boots global behaviors (timers, etc.)
    bootBehaviors() {
        this.bootTimers();
    }

    bootTimers() {
        const referenceDateOffset = 978307200; // seconds between 1970 and 2001 reference dates
        document.querySelectorAll('[mist-behavior="timer"]').forEach(element => {
            if (element._mistTimer) return;
            // Expects encoded Swift Date (CFAbsoluteTime: seconds since 2001-01-01)
            const swiftTimestamp = parseFloat(element.dataset.startTimestamp);
            if (Number.isNaN(swiftTimestamp)) return;

            const startedAt = swiftTimestamp + referenceDateOffset;
            const update = () => {
                const now = Date.now() / 1000;
                const elapsed = Math.max(now - startedAt, 0);
                element.textContent = `${elapsed.toFixed(1)}s`;
            };

            update();

            element._mistTimer = setInterval(() => {
                // Stop if element is removed from DOM
                if (!document.body.contains(element)) {
                    clearInterval(element._mistTimer);
                    element._mistTimer = null;
                    return;
                }

                // Stop if element no longer has the timer behavior (e.g. morphed into static span)
                if (element.getAttribute('mist-behavior') !== 'timer') {
                    clearInterval(element._mistTimer);
                    element._mistTimer = null;
                    return;
                }

                update();
            }, 100);
        });
    }

    handleAction(event) {

        const target = event.target.closest('[mist-action]');

        if (!target) return;

        const actionName = target.getAttribute('mist-action');

        // 1. Find component, but ID is now optional
        const componentElement = target.closest('[mist-component]');

        if (!componentElement || !actionName) return;

        const componentName = componentElement.getAttribute('mist-component');
        // 2. ID can now be null, which is valid
        const componentId = componentElement.getAttribute('mist-id');

        // 3. Only require componentName. componentId is optional.
        if (!componentName) return;

        if (this.isConnected()) {

            const message = {
                action: {
                    component: componentName,
                    id: componentId, // Will correctly send `id: null` if not found
                    action: actionName
                }
            };

            this.socket.send(JSON.stringify(message));

            // 4. Update log message to handle null ID
            const idLog = componentId ? componentId.substring(0, 8) : 'null';
            console.log(`[Client] Action sent to server: ${componentName}.${actionName} (${idLog})`);
        }
    }

    isConnected() { return this.socket?.readyState === WebSocket.OPEN; }
    isConnecting() { return this.socket?.readyState === WebSocket.CONNECTING; }

    connect() {

        if (this.isConnected() || this.isConnecting()) return;
        if (this.socket) { this.socket.close(); this.socket = null; }

        // Use URL from config
        this.socket = new WebSocket(this.config.url);

        this.socket.onopen = () => {

            if (this.timer) { clearInterval(this.timer); this.timer = null; }

            this.subscribeToPageComponents();

            this.bootBehaviors();
        };

        this.socket.onmessage = (event) => {
            try {

                const data = JSON.parse(event.data);

                // Instance-based component messages (with ID)
                if (data.createInstanceComponent) {
                    const { component, id, html } = data.createInstanceComponent;
                    const existingElements = document.querySelectorAll(this.buildComponentSelector(component, id));

                    // If component already exists, treat as update
                    if (existingElements.length > 0) {
                        existingElements.forEach(element => {
                            morphdom(element, html);
                        });
                        console.log(`[Client] Component updated: ${component} (${id.substring(0, 8)})`);
                    } else {
                        // Find container that accepts this component
                        const containers = document.querySelectorAll('[mist-container]');

                        for (const container of containers) {
                            const acceptedComponents = container.getAttribute('mist-container').split(',').map(c => c.trim());

                            if (acceptedComponents.includes(component)) {
                                // Check for custom insertion position (default: 'beforeend' to append)
                                const insertPosition = container.getAttribute('mist-insert-position') || 'beforeend';
                                container.insertAdjacentHTML(insertPosition, html);
                                console.log(`[Client] Component created: ${component} (${id.substring(0, 8)})`);
                                break;
                            }
                        }
                    }
                }
                else if (data.updateInstanceComponent) {
                    const { component, id, html } = data.updateInstanceComponent;
                    const elements = document.querySelectorAll(this.buildComponentSelector(component, id));

                    elements.forEach(element => {
                        morphdom(element, html);
                    });

                    console.log(`[Client] Component updated: ${component} (${id.substring(0, 8)})`);
                }
                else if (data.deleteInstanceComponent) {
                    const { component, id } = data.deleteInstanceComponent;
                    const elements = document.querySelectorAll(this.buildComponentSelector(component, id));

                    elements.forEach(element => {
                        element.remove();
                    });

                    console.log(`[Client] Component deleted: ${component} (${id.substring(0, 8)})`);
                }
                // Query-based component messages (no ID)
                else if (data.updateQueryComponent) {
                    const { component, html } = data.updateQueryComponent;
                    const existingElements = document.querySelectorAll(this.buildComponentSelector(component, null));

                    // If component already exists, replace it
                    if (existingElements.length > 0) {
                        existingElements.forEach(element => {
                            morphdom(element, html);
                        });
                        console.log(`[Client] Component updated: ${component}`);
                    } else {
                        // Find container that accepts this component
                        const containers = document.querySelectorAll('[mist-container]');

                        for (const container of containers) {
                            const acceptedComponents = container.getAttribute('mist-container').split(',').map(c => c.trim());

                            if (acceptedComponents.includes(component)) {
                                // Check for custom insertion position (default: 'beforeend' to append)
                                const insertPosition = container.getAttribute('mist-insert-position') || 'beforeend';
                                container.insertAdjacentHTML(insertPosition, html);
                                console.log(`[Client] Component created: ${component}`);
                                break;
                            }
                        }
                    }
                }
                else if (data.deleteQueryComponent) {
                    const { component } = data.deleteQueryComponent;
                    const elements = document.querySelectorAll(this.buildComponentSelector(component, null));

                    elements.forEach(element => {
                        element.remove();
                    });

                    console.log(`[Client] Component deleted: ${component}`);
                }
                else if (data.actionResult) {
                    const { component, id, action, result, message } = data.actionResult;
                    const isSuccess = result.success !== undefined;
                    const resultType = isSuccess ? '✅' : '❌';
                    const idLog = id ? id.substring(0, 8) : 'null';

                    console.log(`[Server] Action result ${resultType}: ${component}.${action} (${idLog}, ${message})`);
                }
                else if (data.text) {
                    const { message } = data.text;
                    console.log(`[Server] Message: ${message}`);
                }
                else {
                    console.log(`[Client] Unhandled server message (raw): ${event.data}`);
                }

                this.bootBehaviors();
            }
            catch (error) {
                console.error(`[Client] Error parsing server message: ${error}`);
            }
        };

        this.socket.onclose = () => {

            if (this.timer) return

            console.log("[Client] WebSocket closed: Reconnecting in 1s");

            setTimeout(() => {
                this.connect();

                this.timer = setInterval(() => {
                    this.connect();
                },
                    this.interval);
            },
                this.initialDelay);
        };
    }

    // Helper function to build component selector
    buildComponentSelector(component, id) {
        if (id) {
            return `[mist-component="${component}"][mist-id="${id}"]`;
        } else {
            return `[mist-component="${component}"]`;
        }
    }

    visibilityChange() {
        if (document.visibilityState === "visible") {
            console.log('[Client] Document visibility changed to visible: Connecting...');
            this.connect();
        }
    }
}

// Capture the script element immediately to read attributes
const mistScript = document.currentScript;

// Wait for the DOM to be fully loaded before executing the code
document.addEventListener('DOMContentLoaded', function () {
    let path = '/mist/ws/'; // Default path

    if (mistScript) {
        const dataUrl = mistScript.getAttribute('data-url');
        if (dataUrl) {
            path = dataUrl;
        }
    }

    // Construct full URL
    const protocol = 'wss://';
    const host = window.location.host;
    const url = `${protocol}${host}${path}`;

    window.ws = new MistSocket({ url: url });
    window.ws.connect();
});
