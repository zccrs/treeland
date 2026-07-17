// Copyright (C) 2026 UnionTech Software Technology Co., Ltd.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

#include <cmath>
#include <algorithm>

#include <QGuiApplication>
#include <QImage>
#include <QQmlApplicationEngine>
#include <QQuickItem>
#include <QQuickItemGrabResult>
#include <QQuickWindow>
#include <QSignalSpy>
#include <QTest>

#include <woutputrenderwindow.h>
#include <woutputviewport.h>
#include <qwlogging.h>
#include <wserver.h>

#include "TestHelper.h"

WAYLIB_SERVER_USE_NAMESPACE
QW_USE_NAMESPACE

/// Liquid Glass effect test using waylib's headless backend for OpenGL.
///
/// A custom main() sets up the waylib QPA platform with WLR_BACKENDS=headless
/// before QGuiApplication, giving us a real OpenGL context via Mesa llvmpipe
/// — no display server or xvfb-run needed.  The TestGlass QML module bundles
/// GlassEffect.qml + shaders, and TestWindow.qml wraps the test scene in an
/// OutputRenderWindow + OutputItem so it renders through waylib's scene graph.
///
/// Property tests read derived values at runtime; rendering tests use
/// grabToImage to capture and compare images.
class GlassEffectTest : public QObject
{
    Q_OBJECT

public:
    static void setGlobals(WOutputRenderWindow *w, QQuickItem *s, QQuickItem *g, TestHelper *h)
    {
        m_window = w;
        m_scene = s;
        m_glass = g;
        m_helper = h;
    }

private:
    static inline WOutputRenderWindow *m_window = nullptr;
    static inline QQuickItem *m_scene = nullptr;
    static inline QQuickItem *m_glass = nullptr;
    static inline TestHelper *m_helper = nullptr;

    /// Grab an item to a QImage (asynchronous — waits for ready).
    static QImage grabImage(QQuickItem *item, const QSize &size = QSize(256, 256))
    {
        auto result = item->grabToImage(size);
        if (!result)
            return {};

        QSignalSpy spy(result.data(), &QQuickItemGrabResult::ready);
        spy.wait(5000);
        return result->image();
    }

    /// Count pixels that differ between two images of the same size.
    static int pixelDiffCount(const QImage &a, const QImage &b)
    {
        if (a.size() != b.size() || a.format() != b.format())
            return -1;

        int count = 0;
        const int w = a.width();
        const int h = a.height();
        for (int y = 0; y < h; ++y) {
            const auto *pa = reinterpret_cast<const QRgb *>(a.scanLine(y));
            const auto *pb = reinterpret_cast<const QRgb *>(b.scanLine(y));
            for (int x = 0; x < w; ++x) {
                if (pa[x] != pb[x])
                    ++count;
            }
        }
        return count;
    }

    static int colorDistance(QRgb a, QRgb b)
    {
        return std::abs(qRed(a) - qRed(b))
            + std::abs(qGreen(a) - qGreen(b))
            + std::abs(qBlue(a) - qBlue(b))
            + std::abs(qAlpha(a) - qAlpha(b));
    }

    static int regionDiffCount(const QImage &a, const QImage &b, const QRect &region, int minDistance = 0)
    {
        if (a.size() != b.size() || a.format() != b.format())
            return -1;

        int count = 0;
        const QRect bounded = region.intersected(a.rect());
        for (int y = bounded.top(); y <= bounded.bottom(); ++y) {
            const auto *pa = reinterpret_cast<const QRgb *>(a.scanLine(y));
            const auto *pb = reinterpret_cast<const QRgb *>(b.scanLine(y));
            for (int x = bounded.left(); x <= bounded.right(); ++x) {
                if (colorDistance(pa[x], pb[x]) > minDistance)
                    ++count;
            }
        }
        return count;
    }

    static bool requiresShaderRendering(const char *testFunction)
    {
        static constexpr const char *renderingTests[] = {
            "powerFactorProducesTransparentCorners",
            "powerFactorChangesShape",
            "refractionParamsChangeRender",
            "glowWeightChangesRender",
            "noiseChangesRender",
            "zeroBlurMultiplierStillAppliesGaussianBlur",
            "blurAmountAndMultiplierChangeRenderedBlurStrength",
            "blurToggleProducesDifferentRender",
        };

        for (const auto *name : renderingTests) {
            if (qstrcmp(testFunction, name) == 0)
                return true;
        }
        return false;
    }

    static bool shaderRenderingAvailable()
    {
        return m_helper && !m_helper->usesSoftwareRenderer();
    }

    /// Reset glass to default property values (called before each test).
    void resetGlass()
    {
        m_glass->setProperty("blurEnabled", false);
        m_glass->setProperty("blurMax", 32);
        m_glass->setProperty("blurAmount", 1.0);
        m_glass->setProperty("blurMultiplier", 0.0);
        m_glass->setProperty("powerFactor", 3.0);
        m_glass->setProperty("fPower", 1.0);
        m_glass->setProperty("a", 0.7);
        m_glass->setProperty("b", 2.3);
        m_glass->setProperty("c", 5.2);
        m_glass->setProperty("d", 6.9);
        m_glass->setProperty("noise", 0.06);
        m_glass->setProperty("glowWeight", 0.25);
        m_glass->setProperty("glowBias", 0.0);
        m_glass->setProperty("glowEdge0", 0.5);
        m_glass->setProperty("glowEdge1", -0.5);
        m_glass->setProperty("brightness", 0.0);
        m_glass->setProperty("contrast", 0.0);
        m_glass->setProperty("saturation", 0.0);
        m_glass->setProperty("colorization", 0.0);
        QTest::qWait(50);
    }

private Q_SLOTS:

    void initTestCase()
    {
        QVERIFY(m_window);
        QVERIFY(m_scene);
        QVERIFY(m_glass);
    }

    void init()
    {
        if (requiresShaderRendering(QTest::currentTestFunction()) && !shaderRenderingAvailable()) {
            QSKIP("Shader rendering checks require OpenGL; the software renderer "
                  "does not run ShaderEffect/MultiEffect output");
        }
    }

    void cleanup()
    {
        resetGlass();
    }

    // ── Property tests: verify QML property exposure ───────────────────

    void overShiftedParamsAreQmlProperties()
    {
        const QList<QByteArray> propertyNames = {
            "powerFactor", "fPower", "a", "b", "c", "d",
            "noise", "glowWeight", "glowBias", "glowEdge0", "glowEdge1",
            "blurEnabled", "blurMax", "blurAmount", "blurMultiplier",
            "brightness", "contrast", "saturation", "colorization",
        };

        for (const QByteArray &name : propertyNames) {
            QVERIFY2(m_glass->metaObject()->indexOfProperty(name.constData()) >= 0,
                     qPrintable(QStringLiteral("GlassEffect must expose %1 as a real QML property")
                                    .arg(QString::fromLatin1(name))));
        }
    }

    void shaderReceivesOverShiftedParams()
    {
        auto *shader = m_glass->findChild<QObject *>("glassShader");
        QVERIFY(shader);

        QVERIFY(m_glass->setProperty("powerFactor", 4.0));
        QVERIFY(m_glass->setProperty("fPower", 1.5));
        QVERIFY(m_glass->setProperty("a", 1.2));
        QVERIFY(m_glass->setProperty("b", 3.0));
        QVERIFY(m_glass->setProperty("c", 4.0));
        QVERIFY(m_glass->setProperty("d", 7.5));
        QVERIFY(m_glass->setProperty("noise", 0.1));
        QVERIFY(m_glass->setProperty("glowWeight", 0.5));
        QVERIFY(m_glass->setProperty("glowBias", 0.2));
        QVERIFY(m_glass->setProperty("glowEdge0", 0.3));
        QVERIFY(m_glass->setProperty("glowEdge1", -0.3));
        QTest::qWait(10);

        QCOMPARE(shader->property("powerFactor").toReal(), 4.0);
        QCOMPARE(shader->property("fPower").toReal(), 1.5);
        QCOMPARE(shader->property("a").toReal(), 1.2);
        QCOMPARE(shader->property("b").toReal(), 3.0);
        QCOMPARE(shader->property("c").toReal(), 4.0);
        QCOMPARE(shader->property("d").toReal(), 7.5);
        QCOMPARE(shader->property("grainAmount").toReal(), 0.1);
        QCOMPARE(shader->property("glowBias").toReal(), 0.2);
        QCOMPARE(shader->property("glowEdge0").toReal(), 0.3);
        QCOMPARE(shader->property("glowEdge1").toReal(), -0.3);
    }

    void multiEffectEnabledReflectsBlurAndColorParams()
    {
        // Default scene: blurEnabled=false, all color params=0 → false
        m_glass->setProperty("blurEnabled", false);
        m_glass->setProperty("brightness", 0.0);
        m_glass->setProperty("contrast", 0.0);
        m_glass->setProperty("saturation", 0.0);
        m_glass->setProperty("colorization", 0.0);
        QTest::qWait(10);
        QVERIFY(!m_glass->property("multiEffectEnabled").toBool());

        // blurEnabled → true
        m_glass->setProperty("blurEnabled", true);
        QTest::qWait(10);
        QVERIFY(m_glass->property("multiEffectEnabled").toBool());

        // Non-zero brightness alone → true
        m_glass->setProperty("blurEnabled", false);
        m_glass->setProperty("brightness", 0.05);
        QTest::qWait(10);
        QVERIFY(m_glass->property("multiEffectEnabled").toBool());

        // Non-zero contrast alone → true
        m_glass->setProperty("brightness", 0.0);
        m_glass->setProperty("contrast", -0.12);
        QTest::qWait(10);
        QVERIFY(m_glass->property("multiEffectEnabled").toBool());

        // Non-zero saturation alone → true
        m_glass->setProperty("contrast", 0.0);
        m_glass->setProperty("saturation", -0.15);
        QTest::qWait(10);
        QVERIFY(m_glass->property("multiEffectEnabled").toBool());

        // Non-zero colorization alone → true
        m_glass->setProperty("saturation", 0.0);
        m_glass->setProperty("colorization", 0.12);
        QTest::qWait(10);
        QVERIFY(m_glass->property("multiEffectEnabled").toBool());
    }

    // ── Rendering tests: grabToImage + image comparison ───────────────

    void grabIsDeterministic()
    {
        const QImage img1 = grabImage(m_scene);
        QVERIFY(!img1.isNull());

        const QImage img2 = grabImage(m_scene);
        QVERIFY(!img2.isNull());

        // Same scene, same settings → identical output
        QCOMPARE(img1, img2);
    }

    void powerFactorProducesTransparentCorners()
    {
        // Default powerFactor=3 → superellipse SDF discards corners.
        // The shape fills the item but rounds the corners.
        QTest::qWait(50);

        // Grab the glass item directly so the backdrop doesn't fill
        // transparent corners.
        const QImage img = grabImage(m_glass);
        QVERIFY(!img.isNull());

        const int w = img.width();
        const int h = img.height();
        const int offset = 2;

        const QList<QPoint> cornerPixels = {
            {offset, offset},                       // top-left
            {w - 1 - offset, offset},               // top-right
            {offset, h - 1 - offset},               // bottom-left
            {w - 1 - offset, h - 1 - offset},        // bottom-right
        };

        for (const auto &pt : cornerPixels) {
            const QRgb px = img.pixel(pt.x(), pt.y());
            QVERIFY2(qAlpha(px) == 0,
                     qPrintable(QStringLiteral("corner pixel (%1,%2) should be transparent, got alpha=%3")
                                    .arg(pt.x()).arg(pt.y()).arg(qAlpha(px))));
        }

        // Center pixel should be opaque (inside the superellipse)
        const QRgb centerPx = img.pixel(w / 2, h / 2);
        QVERIFY2(qAlpha(centerPx) == 255,
                 qPrintable(QStringLiteral("center pixel should be opaque, got alpha=%1")
                                .arg(qAlpha(centerPx))));
    }

    void powerFactorChangesShape()
    {
        // powerFactor=2 → circle (|x|^2+|y|^2=r^2), small coverage
        // powerFactor=6 → near-rectangle, large coverage
        // The two should produce visibly different renders because the
        // covered (opaque) area differs.

        m_glass->setProperty("powerFactor", 2.0);
        QTest::qWait(50);
        const QImage circular = grabImage(m_glass);
        QVERIFY(!circular.isNull());

        m_glass->setProperty("powerFactor", 6.0);
        QTest::qWait(50);
        const QImage squarish = grabImage(m_glass);
        QVERIFY(!squarish.isNull());

        // The squarish shape covers more area → more opaque pixels.
        int circularOpaque = 0, squarishOpaque = 0;
        const int w = circular.width();
        const int h = circular.height();
        for (int y = 0; y < h; ++y) {
            const auto *pc = reinterpret_cast<const QRgb *>(circular.scanLine(y));
            const auto *ps = reinterpret_cast<const QRgb *>(squarish.scanLine(y));
            for (int x = 0; x < w; ++x) {
                if (qAlpha(pc[x]) > 128) ++circularOpaque;
                if (qAlpha(ps[x]) > 128) ++squarishOpaque;
            }
        }
        QVERIFY2(squarishOpaque > circularOpaque,
                 qPrintable(QStringLiteral("powerFactor=6 should cover more area than powerFactor=2: circle=%1 square=%2")
                                .arg(circularOpaque).arg(squarishOpaque)));
    }

    void refractionParamsChangeRender()
    {
        // b=0 → f(dist)=1 everywhere → no refraction (identity sampling)
        // b=4.0 → strong refraction at edges
        m_glass->setProperty("blurEnabled", false);
        m_glass->setProperty("b", 0.0);
        m_glass->setProperty("noise", 0.0);
        QTest::qWait(50);

        const QImage noRefraction = grabImage(m_scene);
        QVERIFY(!noRefraction.isNull());

        m_glass->setProperty("b", 4.0);
        QTest::qWait(50);

        const QImage withRefraction = grabImage(m_scene);
        QVERIFY(!withRefraction.isNull());

        // Edge bands should show refraction differences (backdrop has
        // contrast bars).  Center should be relatively stable.
        const QList<QRect> edgeBands = {
            QRect(0, 56, 72, 144),
            QRect(184, 56, 72, 144),
            QRect(56, 0, 144, 72),
            QRect(56, 184, 144, 72),
        };
        const QRect centerInterior(104, 104, 48, 48);

        int edgeChanged = 0, edgePixels = 0;
        for (const QRect &band : edgeBands) {
            edgeChanged += regionDiffCount(noRefraction, withRefraction, band, 6);
            edgePixels += band.width() * band.height();
        }
        const int centerChanged = regionDiffCount(noRefraction, withRefraction, centerInterior, 6);

        QVERIFY2(edgeChanged > edgePixels / 20,
                 qPrintable(QStringLiteral("refraction b=4 should visibly change edge sampling: edgeChanged=%1 regionPixels=%2")
                                .arg(edgeChanged).arg(edgePixels)));
        QVERIFY2(edgeChanged > centerChanged,
                 qPrintable(QStringLiteral("refraction should be edge-dominated: edgeChanged=%1 centerChanged=%2")
                                .arg(edgeChanged).arg(centerChanged)));
    }

    void glowWeightChangesRender()
    {
        // glowWeight=0 → no angular glow
        // glowWeight=0.5 → visible angular brightness variation
        m_glass->setProperty("blurEnabled", false);
        m_glass->setProperty("noise", 0.0);
        m_glass->setProperty("glowWeight", 0.0);
        QTest::qWait(50);

        const QImage noGlow = grabImage(m_scene);
        QVERIFY(!noGlow.isNull());

        m_glass->setProperty("glowWeight", 0.5);
        QTest::qWait(50);

        const QImage withGlow = grabImage(m_scene);
        QVERIFY(!withGlow.isNull());

        const int diff = pixelDiffCount(noGlow, withGlow);
        QVERIFY2(diff > 0,
                 qPrintable(QStringLiteral("glowWeight change must produce different output, got %1 differing pixels").arg(diff)));
    }

    void noiseChangesRender()
    {
        // noise=0 → no film grain
        // noise=0.3 → strong grain (±0.15 per channel ≈ ±38 in 8-bit)
        m_glass->setProperty("blurEnabled", false);
        m_glass->setProperty("glowWeight", 0.0);
        m_glass->setProperty("noise", 0.0);
        QTest::qWait(50);

        const QImage clean = grabImage(m_glass);
        QVERIFY(!clean.isNull());

        m_glass->setProperty("noise", 0.3);
        QTest::qWait(50);

        const QImage grainy = grabImage(m_glass);
        QVERIFY(!grainy.isNull());

        const int diff = pixelDiffCount(clean, grainy);
        QVERIFY2(diff > 100,
                 qPrintable(QStringLiteral("noise=0.3 should add visible grain, got %1 differing pixels").arg(diff)));
    }

    void zeroBlurMultiplierStillAppliesGaussianBlur()
    {
        m_glass->setProperty("blurEnabled", true);
        m_glass->setProperty("blurMax", 48);
        m_glass->setProperty("blurAmount", 1.0);
        QVERIFY(m_glass->setProperty("blurMultiplier", 0.0));
        QTest::qWait(50);

        const QImage defaultQualityBlur = grabImage(m_scene);
        QVERIFY(!defaultQualityBlur.isNull());

        m_glass->setProperty("blurEnabled", false);
        QTest::qWait(50);

        const QImage withoutBlur = grabImage(m_scene);
        QVERIFY(!withoutBlur.isNull());

        const QRect centerContrastFeature(92, 92, 72, 72);
        const int changedPixels = regionDiffCount(defaultQualityBlur, withoutBlur, centerContrastFeature, 4);
        QVERIFY2(changedPixels > centerContrastFeature.width() * centerContrastFeature.height() / 5,
                 qPrintable(QStringLiteral("blurMultiplier=0 must keep blur active instead of disabling it: changedPixels=%1 regionPixels=%2")
                                .arg(changedPixels)
                                .arg(centerContrastFeature.width() * centerContrastFeature.height())));
    }

    void blurAmountAndMultiplierChangeRenderedBlurStrength()
    {
        m_glass->setProperty("blurEnabled", true);
        m_glass->setProperty("blurMax", 48);
        QVERIFY2(m_glass->setProperty("blurAmount", 0.15),
                 "GlassEffect must expose blurAmount as a runtime QML property");
        QVERIFY2(m_glass->setProperty("blurMultiplier", 0.5),
                 "GlassEffect must expose blurMultiplier as a runtime QML property");
        QTest::qWait(50);

        const QImage weakBlur = grabImage(m_scene);
        QVERIFY(!weakBlur.isNull());

        QVERIFY(m_glass->setProperty("blurAmount", 1.0));
        QVERIFY(m_glass->setProperty("blurMultiplier", 2.0));
        QTest::qWait(50);

        const QImage strongBlur = grabImage(m_scene);
        QVERIFY(!strongBlur.isNull());

        const QRect centerContrastFeature(92, 92, 72, 72);
        const int changedPixels = regionDiffCount(weakBlur, strongBlur, centerContrastFeature, 4);
        QVERIFY2(changedPixels > centerContrastFeature.width() * centerContrastFeature.height() / 5,
                 qPrintable(QStringLiteral("blurAmount/blurMultiplier must visibly change the sampled backdrop blur: changedPixels=%1 regionPixels=%2")
                                .arg(changedPixels)
                                .arg(centerContrastFeature.width() * centerContrastFeature.height())));
    }

    void blurToggleProducesDifferentRender()
    {
        m_glass->setProperty("blurEnabled", true);
        m_glass->setProperty("blurMax", 36);
        QTest::qWait(50);

        const QImage withBlur = grabImage(m_scene);
        QVERIFY(!withBlur.isNull());

        m_glass->setProperty("blurEnabled", false);
        QTest::qWait(50);

        const QImage withoutBlur = grabImage(m_scene);
        QVERIFY(!withoutBlur.isNull());

        QVERIFY(withBlur != withoutBlur);
    }
};

int main(int argc, char *argv[])
{
    // Headless wlroots backend — no display server needed.
    qputenv("WLR_BACKENDS", "headless");

    qw_log::init();
    WServer::initializeQPA();


    QGuiApplication app(argc, argv);
    QQmlApplicationEngine engine;

    engine.loadFromModule("TestGlass", "TestWindow");
    if (engine.rootObjects().isEmpty())
        return 1;

    auto *root = engine.rootObjects().first();
    auto *window = root->findChild<WOutputRenderWindow *>("renderWindow");
    Q_ASSERT(window);

    auto *helper = engine.singletonInstance<TestHelper *>("TestGlass", "TestHelper");
    Q_ASSERT(helper);
    helper->initProtocols(window, &engine);
    window->setVisible(true);  // QQuickItem::grabToImage requires isVisible

    // Wait for the headless output to be created and the scene to be ready.
    QSignalSpy initSpy(window, &WOutputRenderWindow::outputViewportInitialized);
    if (initSpy.isEmpty())
        initSpy.wait(5000);
    QTest::qWait(500); // let the scene graph settle

    auto *scene = window->findChild<QQuickItem *>("glassScene");
    Q_ASSERT(scene);
    auto *glass = window->findChild<QQuickItem *>("glassEffect");
    Q_ASSERT(glass);

    GlassEffectTest::setGlobals(window, scene, glass, helper);

    GlassEffectTest test;
    int result = QTest::qExec(&test, argc, argv);
    // wlroots objects (renderer, allocator, compositor) crash during normal
    // destructor unwinding — skip cleanup and exit immediately.
    std::_Exit(result);
}

#include "main.moc"
