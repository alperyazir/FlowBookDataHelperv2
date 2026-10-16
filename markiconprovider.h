#ifndef MARKICONPROVIDER_H
#define MARKICONPROVIDER_H

// Mark-with-X marks in any colour: "image://markicon/<dot|x|tick>/<rrggbb>".
// Renders :/icons/mark_<type>.svg with its colour (#d2232b, the answer colour
// the SVGs are drawn in) swapped for the requested one, at the size the Image
// asks for (sourceSize), so the mark stays sharp at any box size. The SVGs
// stay the only source of the shapes. Same file in FlowBook and
// FlowBookDataHelper2.

#include <QColor>
#include <QFile>
#include <QImage>
#include <QPainter>
#include <QQuickImageProvider>
#include <QSvgRenderer>

class MarkIconProvider : public QQuickImageProvider
{
public:
    MarkIconProvider() : QQuickImageProvider(QQuickImageProvider::Image) {}

    static constexpr const char *kDefaultColor = "#d2232b";

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override
    {
        const QStringList parts = id.split('/');
        QString type = parts.value(0);
        if (type != QLatin1String("x") && type != QLatin1String("tick"))
            type = QStringLiteral("dot");
        QColor color(QLatin1Char('#') + parts.value(1));
        if (!color.isValid())
            color = QColor(kDefaultColor);

        QFile f(QStringLiteral(":/icons/mark_%1.svg").arg(type));
        if (!f.open(QIODevice::ReadOnly))
            return QImage();
        QByteArray svg = f.readAll();
        svg.replace(kDefaultColor, color.name().toLatin1());

        // Always square (the marks are drawn on a square canvas), sized to the
        // shorter side of the box: rendering into a wide box's own shape would
        // stretch the dot into an ellipse and flatten the X/tick.
        QSvgRenderer renderer(svg);
        QSize out = renderer.defaultSize();
        const int w = requestedSize.width(), h = requestedSize.height();
        const int side = (w > 0 && h > 0) ? qMin(w, h) : qMax(w, h);
        if (side > 0)
            out = QSize(side, side);
        if (size)
            *size = out;

        QImage img(out, QImage::Format_ARGB32_Premultiplied);
        img.fill(Qt::transparent);
        QPainter p(&img);
        p.setRenderHint(QPainter::Antialiasing);
        renderer.render(&p);
        return img;
    }
};

#endif // MARKICONPROVIDER_H
