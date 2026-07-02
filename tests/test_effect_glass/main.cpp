// Copyright (C) 2026 UnionTech Software Technology Co., Ltd.
// SPDX-License-Identifier: Apache-2.0 OR LGPL-3.0-only OR GPL-2.0-only OR GPL-3.0-only

#include <QFile>
#include <QObject>
#include <QString>
#include <QTest>

class GlassEffectTest : public QObject
{
    Q_OBJECT

private:
    static QString readSource(const QString &relativePath)
    {
        QFile file(QStringLiteral(SOURCE_DIR) + QLatin1Char('/') + relativePath);
        if (!file.open(QIODevice::ReadOnly | QIODevice::Text))
            return QString();

        return QString::fromUtf8(file.readAll());
    }

private Q_SLOTS:
    void shaderFilesExist()
    {
        QVERIFY2(QFile::exists(QStringLiteral(SOURCE_DIR "/misc/shaders/liquidglass.vert")),
                 "liquidglass.vert must exist");
        QVERIFY2(QFile::exists(QStringLiteral(SOURCE_DIR "/misc/shaders/liquidglass.frag")),
                 "liquidglass.frag must exist");
    }

    void treelandModuleIncludesGlassQml()
    {
        const QString cmake = readSource(QStringLiteral("src/CMakeLists.txt"));
        QVERIFY2(!cmake.isEmpty(), "src/CMakeLists.txt must be readable");
        QVERIFY(cmake.contains(QStringLiteral("core/qml/Effects/Glass.qml")));
    }

    void shaderResourcesAreCompiled()
    {
        const QString cmake = readSource(QStringLiteral("src/CMakeLists.txt"));
        QVERIFY2(!cmake.isEmpty(), "src/CMakeLists.txt must be readable");
        QVERIFY(cmake.contains(QStringLiteral("${PROJECT_RESOURCES_DIR}/shaders/liquidglass.vert")));
        QVERIFY(cmake.contains(QStringLiteral("${PROJECT_RESOURCES_DIR}/shaders/liquidglass.frag")));
    }

    void glassQmlExposesDocumentedDefaults()
    {
        const QString qml = readSource(QStringLiteral("src/core/qml/Effects/Glass.qml"));
        QVERIFY2(!qml.isEmpty(), "Glass.qml must be readable");
        QVERIFY(qml.contains(QStringLiteral("property real radius: 0")));
        QVERIFY(qml.contains(QStringLiteral("property bool blurEnabled: true")));
        QVERIFY(qml.contains(QStringLiteral("property int blurMax: 32")));
        QVERIFY(qml.contains(QStringLiteral("property real refractionHeight: 24")));
        QVERIFY(qml.contains(QStringLiteral("property real refractionAmount: 10")));
        QVERIFY(qml.contains(QStringLiteral("property real exposure: 1.08")));
        QVERIFY(qml.contains(QStringLiteral("property real saturation: 1.15")));
        QVERIFY(qml.contains(QStringLiteral("property color tintColor: Qt.rgba(1, 1, 1, 0.10)")));
        QVERIFY(qml.contains(QStringLiteral("property color highlightColor: Qt.rgba(1, 1, 1, 0.35)")));
        QVERIFY(qml.contains(QStringLiteral("property real highlightStrength: 0.45")));
    }
};

QTEST_MAIN(GlassEffectTest)
#include "main.moc"
