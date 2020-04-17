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
import Munsell exposing (ColorDict)
import Point3d exposing (Point3d)
import Scene3d
import Scene3d.Material as Material
import Scene3d.Mesh as Mesh
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



---- OBJECT TYPES ----


{-| A WorldEntity is made up of vertices.
A Box has 4 corner points (top face) and 4 on the bottom face = 8 total.
A Cylinder has 1 center point plus 'longitudeLineCount' on the circumference
of both the top and bottom faces.
-}
type ObjectKind
    = Cube
    | Cylinder
    | Sphere
    | Polyline


cubeSize : Length
cubeSize =
    Length.centimeters 90


sphereRadius : Length
sphereRadius =
    Length.centimeters 45


cylinderRadius : Length
cylinderRadius =
    Length.centimeters 20


cylinderLength : Length
cylinderLength =
    Length.centimeters 20


longitudeLineCount : Int
longitudeLineCount =
    30



---- COLORS ----


type alias GlobeColors =
    { xPos : Color
    , xNeg : Color
    , yPos : Color
    , yNeg : Color
    , oPos : Color
    , oNeg : Color
    }



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
    Scene3d.block Scene3d.castsShadows material shape


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
    Scene3d.sphere Scene3d.castsShadows material shape


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
    Scene3d.cylinder Scene3d.castsShadows material shape


matteCylinderAt : WorldPoint3d -> { radius : Length, length : Length } -> Color -> WorldEntity
matteCylinderAt origin size color =
    cylinderAt origin size (Material.matte color)



---- POLYLINES


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
        [ [ equatorCircle colors.xPos radius ]
        , longitudeArcs colors.yPos pointPos radius
        , longitudeArcs colors.yNeg pointNeg radius
        ]



{- / Construct a circular polyline Entity in the sketch plane (xy). -}


equatorCircle : Color -> Length -> WorldEntity
equatorCircle color radius =
    let
        material =
            Material.color color

        startPoint =
            Point3d.meters (Length.inMeters radius) 0 0
    in
    Arc3d.sweptAround Axis3d.z (Angle.degrees 360) startPoint
        |> Arc3d.toPolyline { maxError = Length.meters (Length.inMeters radius / 100.0) }
        |> Mesh.polyline
        |> Scene3d.mesh material


longitudeArcs : Color -> WorldPoint3d -> Length -> WorldEntityList
longitudeArcs color yPoint radius =
    List.range 0 15
        |> List.map
            (\a ->
                longitudeArc color
                    yPoint
                    radius
                    (Angle.degrees (toFloat a * (360.0 / 15.0)))
            )


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
    in
    Arc3d.sweptAround axis (Angle.degrees 180) startPoint
        |> Arc3d.toPolyline { maxError = Length.meters (Length.inMeters radius / 100.0) }
        |> Mesh.polyline
        |> Scene3d.mesh material
