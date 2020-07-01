module World exposing
    ( GlobeColors
    , WorldCoordinates
    , WorldEntity
    , WorldEntityList
    , cubeAt
    , cylinderAt
    , globe
    , matteCubeAt
    , matteCylinderAt
    , matteSphereAt
    , sphereAt
    )

import Angle exposing (Angle)
import Arc3d
import Axis3d
import Block3d
import Color exposing (Color)
import Cylinder3d
import Direction3d
import Frame3d
import Length exposing (Length, Meters)
import Point3d exposing (Point3d)
import Quantity
import Scene3d
import Scene3d.Material as Material
import Scene3d.Mesh as Mesh
import SketchPlane3d
import Sphere3d



-- COORDINATE SYSTEM


{-| Phantom type. Or we could use Physics.WorldCoordinates.
-}
type WorldCoordinates
    = WorldCoordinates


type alias WorldPoint3d =
    Point3d Meters WorldCoordinates


type alias WorldEntity =
    Scene3d.Entity WorldCoordinates


type alias WorldEntityList =
    List WorldEntity



-- CUBES


cubeAt : WorldPoint3d -> Length -> Material.Uniform WorldCoordinates -> WorldEntity
cubeAt origin size material =
    let
        frame =
            Frame3d.atPoint origin

        shape =
            Block3d.centeredOn frame
                ( size, size, size )
    in
    Scene3d.block material shape


matteCubeAt : WorldPoint3d -> Length -> Color -> WorldEntity
matteCubeAt origin size color =
    cubeAt origin size (Material.matte color)



-- SPHERES


sphereAt : WorldPoint3d -> Length -> Material.Textured WorldCoordinates -> WorldEntity
sphereAt origin radius material =
    let
        shape =
            Sphere3d.atPoint origin radius
    in
    Scene3d.sphere material shape


matteSphereAt : WorldPoint3d -> Length -> Color -> WorldEntity
matteSphereAt origin radius color =
    sphereAt origin radius (Material.matte color)



---- CYLINDERS ----


cylinderAt : WorldPoint3d -> { radius : Length, length : Length } -> Material.Uniform WorldCoordinates -> WorldEntity
cylinderAt origin size material =
    let
        shape =
            Cylinder3d.centeredOn
                origin
                Direction3d.z
                size
    in
    Scene3d.cylinder material shape


matteCylinderAt : WorldPoint3d -> { radius : Length, length : Length } -> Color -> WorldEntity
matteCylinderAt origin size color =
    cylinderAt origin size (Material.matte color)



---- GLOBE COLORS ----


type alias GlobeColors =
    { xPos : Color
    , xNeg : Color
    , yPos : Color
    , yNeg : Color
    , oPos : Color
    , oNeg : Color
    }



---- GLOBE POLYLINES


longitudeLineCount : Int
longitudeLineCount =
    12


halfLatitudeLineCount : Int
halfLatitudeLineCount =
    6


globe : Length -> GlobeColors -> WorldEntityList
globe radius colors =
    let
        rInMeters =
            Length.inMeters radius

        pointPos =
            Point3d.meters 0 rInMeters 0

        pointNeg =
            Point3d.meters 0 -rInMeters 0
    in
    List.concat
        [ latitudeArcs colors.xPos radius
        , longitudeArcs colors.yPos pointPos radius
        , longitudeArcs colors.yNeg pointNeg radius
        ]


latitudeArcs : Color -> Length -> WorldEntityList
latitudeArcs color radius =
    List.range (1 - halfLatitudeLineCount) (halfLatitudeLineCount - 1)
        |> List.map
            (\a ->
                latitudeArc color
                    radius
                    (Angle.degrees (90.0 * toFloat a / toFloat halfLatitudeLineCount))
            )


{-| Construct a 360 degree arc entity around the z axis.
-}
latitudeArc : Color -> Length -> Angle -> WorldEntity
latitudeArc color radius angle =
    let
        material =
            Material.color color

        startPoint =
            Point3d.rThetaOn SketchPlane3d.xz
                radius
                angle

        maxError =
            Quantity.multiplyBy 0.01 radius
    in
    Arc3d.sweptAround Axis3d.z (Angle.degrees 360) startPoint
        |> Arc3d.toPolyline { maxError = maxError }
        |> Mesh.polyline
        |> Scene3d.mesh material


longitudeArcs : Color -> WorldPoint3d -> Length -> WorldEntityList
longitudeArcs color yPoint radius =
    List.range 0 longitudeLineCount
        |> List.map
            (\a ->
                longitudeArc color
                    yPoint
                    radius
                    (Angle.degrees (360.0 * toFloat a / toFloat longitudeLineCount))
            )


{-| Construct a 180 degree arc entity through one of the poles.
-}
longitudeArc : Color -> WorldPoint3d -> Length -> Angle -> WorldEntity
longitudeArc color yPoint radius angle =
    let
        material =
            Material.color color

        startPoint =
            yPoint
                |> Point3d.rotateAround Axis3d.z angle

        axis =
            Axis3d.x
                |> Axis3d.rotateAround Axis3d.z angle

        maxError =
            Quantity.multiplyBy 0.01 radius
    in
    Arc3d.sweptAround axis (Angle.degrees 180) startPoint
        |> Arc3d.toPolyline { maxError = maxError }
        |> Mesh.polyline
        |> Scene3d.mesh material
