// frame-exact capture: drives qt's animation clock by hand so the video has real timing
// however slow the software renderer is.
//   capture <import paths> <scene.qml> <out dir> <frames> <fps>
#include <QAnimationDriver>
#include <QDir>
#include <QGuiApplication>
#include <QImage>
#include <QQmlEngine>
#include <QQuickView>
#include <cstdio>
#include <cstdlib>

class Clock : public QAnimationDriver {
public:
    qint64 now = 0;
    qint64 elapsed() const override { return now; }
    void step(qint64 ms) {
        now += ms;
        advance();
    }
};

int main(int argc, char** argv) {
    if (argc < 6) {
        fprintf(stderr, "usage: capture <imports> <scene.qml> <outdir> <frames> <fps>\n");
        return 64;
    }
    QGuiApplication app(argc, argv);
    Clock clock;
    clock.install();

    QQuickView view;
    for (const auto& p : QString(argv[1]).split(':', Qt::SkipEmptyParts))
        view.engine()->addImportPath(p);
    view.setSource(QUrl::fromLocalFile(argv[2]));
    if (view.status() == QQuickView::Error) {
        for (const auto& e : view.errors())
            fprintf(stderr, "ERROR %s\n", qPrintable(e.toString()));
        return 1;
    }
    view.setResizeMode(QQuickView::SizeViewToRootObject);
    view.show();

    const QString out = argv[3];
    const int frames = atoi(argv[4]);
    const double fps = atof(argv[5]);
    QDir().mkpath(out);
    for (int i = 0; i < 5; i++)
        app.processEvents();

    double carry = 0;
    for (int i = 0; i < frames; i++) {
        carry += 1000.0 / fps;
        const qint64 ms = qint64(carry);
        carry -= ms;
        clock.step(ms);
        app.processEvents();
        view.grabWindow().save(QString("%1/f%2.png").arg(out).arg(i, 5, 10, QChar('0')));
    }
    printf("captured %d frames at %.0f fps\n", frames, fps);
    return 0;
}
