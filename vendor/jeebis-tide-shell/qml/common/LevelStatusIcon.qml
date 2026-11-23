import QtQuick

Canvas {
    id: root
    property string kind: "volume"
    property real value: 0
    property color ink: "#242428"

    onKindChanged: requestPaint()
    onValueChanged: requestPaint()
    onInkChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const scale = Math.min(width, height) / 24;
        if (scale <= 0) return;
        ctx.reset();
        ctx.clearRect(0, 0, width, height);
        ctx.translate((width - 24 * scale) / 2, (height - 24 * scale) / 2);
        ctx.scale(scale, scale);
        ctx.fillStyle = root.ink;
        ctx.strokeStyle = root.ink;
        ctx.lineWidth = 1.65;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";

        if (root.kind === "brightness") {
            ctx.beginPath();
            ctx.arc(12, 12, 4.25, 0, 2 * Math.PI);
            ctx.fill();
            const end = 8 + 3 * Math.max(0, Math.min(1, root.value));
            for (let i = 0; i < 6; ++i) {
                const angle = i * Math.PI / 3 - Math.PI / 2;
                const x = Math.cos(angle), y = Math.sin(angle);
                ctx.beginPath();
                ctx.moveTo(12 + 6.3 * x, 12 + 6.3 * y);
                ctx.lineTo(12 + end * x, 12 + end * y);
                ctx.stroke();
            }
        } else {
            ctx.beginPath();
            ctx.moveTo(2, 9);
            ctx.lineTo(5.5, 9);
            ctx.lineTo(11, 4.5);
            ctx.lineTo(11, 19.5);
            ctx.lineTo(5.5, 15);
            ctx.lineTo(2, 15);
            ctx.closePath();
            ctx.fill();
            if (root.kind === "mute") {
                ctx.beginPath();
                ctx.moveTo(15, 9);
                ctx.lineTo(21, 15);
                ctx.moveTo(21, 9);
                ctx.lineTo(15, 15);
                ctx.stroke();
            } else {
                const waves = root.value <= 0 ? 0 : root.value <= 0.33 ? 1 : root.value <= 0.66 ? 2 : 3;
                for (let i = 0; i < waves; ++i) {
                    ctx.beginPath();
                    ctx.arc(9, 12, 5.5 + 3 * i, -0.74, 0.74);
                    ctx.stroke();
                }
            }
        }
    }
}
