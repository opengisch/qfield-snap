import QtQuick
import QtQuick.Controls

import org.qfield
import org.qgis
import Theme

import "qrc:/qml" as QFieldItems

Item {
  id: plugin

  property var mainWindow: iface.mainWindow()
  property var positionSource: iface.findItemByObjectName('positionSource')
  property var dashBoard: iface.findItemByObjectName('dashBoard')
  property var overlayFeatureFormDrawer: iface.findItemByObjectName('overlayFeatureFormDrawer')

  property var candidates: ["photo", "picture", "image", "media", "camera"]

  Component.onCompleted: {
    iface.addItemToPluginsToolbar(snapButton)
  }

  Loader {
    id: cameraLoader
    active: false
    sourceComponent: Component {
      id: cameraComponent
    
      QFieldItems.QFieldCamera {
        id: qfieldCamera
        visible: false
    
        Component.onCompleted: {
          open()
        }
    
        onFinished: (path) => {
          close()
          snap(path)
        }
    
        onCanceled: {
          close()
        }
    
        onClosed: {
          cameraLoader.active = false
        }
      }
    }
  }

  QfToolButton {
    id: snapButton
    bgcolor: Theme.darkGray
    iconSource: Theme.getThemeVectorIcon('ic_camera_photo_black_24dp')
    iconColor: Theme.mainColor
    round: true

    onClicked: {
      dashBoard.ensureEditableLayerSelected()

      if (!positionSource.active || !positionSource.positionInformation.latitudeValid || !positionSource.positionInformation.longitudeValid) {
        mainWindow.displayToast(qsTr('Snap requires positioning to be active and returning a valid position'))
        return
      }
      
      if (dashBoard.activeLayer.geometryType() != Qgis.GeometryType.Point) {
        mainWindow.displayToast(qsTr('Snap requires the active vector layer to be a point geometry'))
        return
      }
      
      let fieldNames = dashBoard.activeLayer.fields.names
      let fieldMatch = false;
      for (const candidate of plugin.candidates) {
        if (fieldNames.indexOf(candidate) >= 0) {
          fieldMatch = true;
          break;
        }
      }
      if (!fieldMatch) {
        mainWindow.displayToast(qsTr('Snap requires the active vector layer to contain a field matching one of the following candidates: %1').arg(plugin.candidates.join(', ')))
        return
      }

      platformUtilities.createDir(qgisProject.homePath, 'DCIM');
      cameraLoader.active = true
    }
  }

  function snap(path) {
    let today = new Date()
    let relativePath = 'DCIM/' + today.getFullYear()
                               + (today.getMonth() +1 ).toString().padStart(2,0)
                               + today.getDate().toString().padStart(2,0)
                               + today.getHours().toString().padStart(2,0)
                               + today.getMinutes().toString().padStart(2,0)
                               + today.getSeconds().toString().padStart(2,0)
                               + '.' + FileUtils.fileSuffix(path)
    platformUtilities.renameFile(path, qgisProject.homePath + '/' + relativePath)
    
    const pos = GeometryUtils.reprojectPoint(positionSource.projectedPosition, positionSource.coordinateTransformer.destinationCrs, dashBoard.activeLayer.crs);
    const elevation = positionSource.positionInformation.elevation;
    let wkt = '';
    switch (dashBoard.activeLayer.wkbType()) {
      case Qgis.WkbType.MultiPointZ:
        wkt = 'MULTIPOINTZ((' + pos.x + ' ' + pos.y + ' ' + elevation + '))';
        break;
      case Qgis.WkbType.MultiPointM:
        wkt = 'MULTIPOINTM((' + pos.x + ' ' + pos.y + ' 0 ))';
        break;
      case Qgis.WkbType.MultiPointZM:
        wkt = 'MULTIPOINTZM((' + pos.x + ' ' + pos.y + ' ' + elevation + ' 0))';
        break;
      case Qgis.WkbType.MultiPoint:
        wkt = 'MULTIPOINT((' + pos.x + ' ' + pos.y + '))';
        break;
      case Qgis.WkbType.PointZ:
        wkt = 'POINTZ(' + pos.x + ' ' + pos.y + ' ' + elevation + ')';
        break;
      case Qgis.WkbType.PointM:
        wkt = 'POINTM(' + pos.x + ' ' + pos.y + ' 0 )';
        break;
      case Qgis.WkbType.PointZM:
        wkt = 'POINTZM(' + pos.x + ' ' + pos.y + ' ' + elevation + ' 0)';
        break;
      case Qgis.WkbType.Point:
        wkt = 'POINT(' + pos.x + ' ' + pos.y + ')';
        break;
      default:
    }
    
    let geometry = GeometryUtils.createGeometryFromWkt(wkt)
    let feature = FeatureUtils.createBlankFeature(dashBoard.activeLayer.fields, geometry)

    let fieldNames = feature.fields.names
    for (const candidate of plugin.candidates) {
      if (fieldNames.indexOf(candidate) > -1) {
        feature.setAttribute(fieldNames.indexOf(candidate), relativePath)
        break;
      }
    }

    overlayFeatureFormDrawer.featureModel.feature = feature
    overlayFeatureFormDrawer.featureModel.resetAttributes(true)
    overlayFeatureFormDrawer.state = 'Add'
    overlayFeatureFormDrawer.open()
  }
}
