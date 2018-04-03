module HueGrid exposing (gridMesh)

import Math.Matrix4 as Mat4 exposing (Mat4, scale3, translate3)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Geometry as Geom
    exposing
        ( GeometryObject
        , AppMesh
        , makeColor
        , makeCube
        , makeCylinder
        , indexedTriangleMesh
        )
import Munsell exposing (ColorDict, hueRange, chromaRange, valueRange)


---- CONSTANTS ----


cylinderSize : Float
cylinderSize =
    90


cubeSize : Float
cubeSize =
    40


x0 : Float
x0 =
    120


spacing : Float
spacing =
    60


valueY : Int -> Float
valueY value =
    toFloat (value - 5) * spacing



---- HUE GRID CUBES ----


gridMesh : ColorDict -> Int -> AppMesh
gridMesh colors hue =
    let
        cylinders =
            valueRange
                |> List.map cylinderForValue

        cubes =
            gridCubes colors hue
    in
        indexedTriangleMesh (cylinders ++ cubes)


cylinderForValue : Int -> GeometryObject
cylinderForValue value =
    let
        grayValue =
            (toFloat value) / 10.0

        color =
            vec3 grayValue grayValue grayValue
    in
        makeCylinder color (xfCylinder value)


xfCylinder : Int -> Mat4
xfCylinder value =
    Mat4.identity
        |> translate3 0 (valueY value) 0
        |> scale3 cylinderSize cubeSize cylinderSize


gridCubes : ColorDict -> Int -> List GeometryObject
gridCubes colors hue =
    List.range 0 3
        |> List.foldl
            (\i acc ->
                let
                    thetaRight =
                        (toFloat i) * pi / 8

                    thetaLeft =
                        (toFloat (8 - i)) * pi / 8

                    xfRight =
                        Mat4.makeRotate thetaRight Geom.worldUp

                    xfLeft =
                        Mat4.makeRotate thetaLeft Geom.worldUp

                    hueRight =
                        (hue + (i * 25)) % 1000

                    hueLeft =
                        (hue + 500 + (i * 25)) % 1000
                in
                    acc
                        ++ cubesForHue colors hueRight xfRight
                        ++ cubesForHue colors hueLeft xfLeft
            )
            []


cubesForHue : ColorDict -> Int -> Mat4 -> List GeometryObject
cubesForHue colors hue xf =
    List.foldl (\value acc -> (cubesForHV colors hue value xf) ++ acc) [] valueRange


cubesForHV : ColorDict -> Int -> Int -> Mat4 -> List GeometryObject
cubesForHV colors hue value xf =
    List.foldl
        (\chroma acc ->
            case cubeInGamut colors hue value chroma xf of
                Just grid ->
                    grid :: acc

                Nothing ->
                    acc
        )
        []
        chromaRange


cubeInGamut : ColorDict -> Int -> Int -> Int -> Mat4 -> Maybe GeometryObject
cubeInGamut colors hue value chroma xf =
    case makeColor colors hue value chroma of
        Just color ->
            Just (cubeWithColor color hue value chroma xf)

        Nothing ->
            Nothing


cubeWithColor : Vec3 -> Int -> Int -> Int -> Mat4 -> GeometryObject
cubeWithColor color hue value chroma xf =
    xfCube hue value chroma
        |> Mat4.mul xf
        |> makeCube color


xfCube : Int -> Int -> Int -> Mat4
xfCube _ value chroma =
    let
        x =
            x0 + (toFloat ((chroma // 2) - 1)) * spacing

        y =
            (toFloat (value - 5)) * spacing
    in
        Mat4.identity
            |> translate3 x y 0
            |> scale3 cubeSize cubeSize cubeSize
