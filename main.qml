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
      if (fieldNames.indexOf('photo') == -1 && fieldNames.indexOf('picture') == -1) {
        mainWindow.displayToast(qsTr('Snap requires the active vector layer to contain a field named \'photo\' or \'picture\''))
        return
      }

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
    
    let pos = positionSource.projectedPosition
    let wkt = 'POINT(' + pos.x + ' ' + pos.y + ')'
    
    let geometry = GeometryUtils.createGeometryFromWkt(wkt)
    let feature = FeatureUtils.createBlankFeature(dashBoard.activeLayer.fields, geometry)
        
    let fieldNames = feature.fields.names
    if (fieldNames.indexOf('photo') > -1) {
      feature.setAttribute(fieldNames.indexOf('photo'), relativePath)
    } else if (fieldNames.indexOf('picture') > -1) {
      feature.setAttribute(fieldNames.indexOf('picture'), relativePath)
    }

    overlayFeatureFormDrawer.featureModel.feature = feature
    overlayFeatureFormDrawer.featureModel.resetAttributes(true)
    overlayFeatureFormDrawer.state = 'Add'
    overlayFeatureFormDrawer.open()
  }
}
