// Move this file (mist.js) to: /Public 

class MistSocket {
    
    constructor() {

        this.socket = null;
        
        this.timer = null;
        this.initialDelay = 1000;
        this.interval = 5000;
        
        document.addEventListener('visibilitychange', () => this.visibilityChange());
        window.addEventListener('online', () => this.connect());
        document.addEventListener('click', (event) => this.handleAction(event));
    }
    
    subscribeToPageComponents() {
        
        console.log("subscribing to server components...");
        
        const uniqueComponents = new Set();
        
        document.querySelectorAll('[mist-component]').forEach(element => {
            
            const component = element.getAttribute('mist-component');
            
            if (component) {
                uniqueComponents.add(component);
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
    
    handleAction(event) {
        
        const target = event.target.closest('[mist-action]');
        
        if (!target) return;
        
        const actionName = target.getAttribute('mist-action');
        const componentElement = target.closest('[mist-component][mist-id]');
        
        if (!componentElement || !actionName) return;
        
        const componentName = componentElement.getAttribute('mist-component');
        const componentId = componentElement.getAttribute('mist-id');
        
        if (!componentName || !componentId) return;
        
        if (this.isConnected()) {
            
            const message = {
                action: {
                    component: componentName,
                    id: componentId,
                    action: actionName
                }
            };
            
            this.socket.send(JSON.stringify(message));
        }
    }
    
    isConnected() { return this.socket?.readyState === WebSocket.OPEN; }
    isConnecting() { return this.socket?.readyState === WebSocket.CONNECTING; }
    
    connect() {

        if (this.isConnected() || this.isConnecting()) return;
        if (this.socket) { this.socket.close(); this.socket = null; }
        
        this.socket = new WebSocket('wss://mottzi.de/mist/ws/');
        
        this.socket.onopen = () => {
            
            if (this.timer) { clearInterval(this.timer); this.timer = null; }
            
            this.subscribeToPageComponents();
        };
        
        this.socket.onmessage = (event) => {
            try {
                
                const data = JSON.parse(event.data);
                
                if (data.update) {
                    const { component, id, html } = data.update;
                    const elements = document.querySelectorAll(`[mist-component="${component}"][mist-id="${id}"]`);
                    
                    elements.forEach(element => {
                        element.outerHTML = html;
                    });
                    
                    console.log(`Server update message: '${component}' (${id})`);
                }
                else if (data.text) {
                    const { message } = data.text;
                    console.log(`Server message: '${message}'`);
                }
                else {
                    console.log(`Unhandled server message (RAW): '${event.data}'`);
                }
            }
            catch (error) {
                console.error(`Error parsing server message: '${error}'`);
            }
        };
        
        this.socket.onclose = () => {

            if (this.timer) return
                
            console.log("WS: ... closed -> Connect in 1s ...");
            
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
    
    visibilityChange() {
        if (document.visibilityState === "visible") {
            console.log('visibilityState === "visible" -> calling connect()')
            this.connect();
        }
    }
}

// Wait for the DOM to be fully loaded before executing the code
document.addEventListener('DOMContentLoaded', function () {
    window.ws = new MistSocket();
    window.ws.connect()
});
