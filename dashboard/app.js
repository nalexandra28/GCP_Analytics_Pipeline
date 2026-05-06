RECENT_ACTIVITY_LENGTH = 10

function getWSLink() {

    if (typeof WS_URL === "undefined") {
        throw new Error("WS_URL is not defined - make sure config.js is loaded before app.js");
    }
    if (!WS_URL || WS_URL.trim() === "") {
        throw new Error("WS_URL is empty");
    }
    if (!WS_URL.startsWith("ws://") && !WS_URL.startsWith("wss://")) {
        throw new Error(`WS_URL has unexpected format: ${WS_URL}`);
    }
    return WS_URL;
}

function renderRecentActivity(newActivity) {

    const container = document.getElementById("recent-activity");

    const p = document.createElement("p");
    p.textContent = `${newActivity.timestamp} — ${newActivity.movieId} ${newActivity.movieTitle}`;
    container.insertBefore(p, container.firstChild);

    if (container.children.length > RECENT_ACTIVITY_LENGTH) {
        container.removeChild(container.lastChild);
    }


}

function connect(url) {

    let retries = 0;
    const maxRetries = 10;
    const maxDelay = 30000;

    function attempt() {

        const ws = new WebSocket(url)

        ws.onopen = () => {

            console.log("On open");
            retries = 0;

        }

        ws.onmessage = (event) => {

            console.log("On Message");

            const data = JSON.parse(event.data);
            console.log("Received:", data);

            const movie = {
                timestamp: data.timestamp,
                movieId: data.data.movieId,
                movieTitle: data.data.movieTitle
            }

            renderRecentActivity(movie)
        }

        ws.onclose = (event) => {

            console.log(`Closed: ${event.code} ${event.reason}`);
            if (event.code === 1000) return;
            if (retries >= maxRetries) {
                console.error("Max retries reached");
                return;
            }
            const base = Math.min(1000 * 2 ** retries, maxDelay);
            const jitter = Math.random() * base * 0.5;
            const delay = base + jitter;
            retries++;
            console.log(`Retrying in ${delay}ms (attempt ${retries}/${maxRetries})`);
            setTimeout(attempt, delay);
        }

        ws.onerror = (error) => {

            console.error("WebSocket error:", error);

        }

    }

    attempt()
}

try {
    const WSLink = getWSLink()
    connect(WSLink)
} catch (err) {
    console.error("WebSocket config error:", err.message);
}


