module HueGrid exposing (buildMesh)

import WebGL
import Math.Matrix4 as Mat4 exposing (Mat4, scale, translate, rotate)
import Math.Vector3 as Vec3 exposing (Vec3, vec3)
import Geometry
    exposing
        ( Cylinder
        , Cube
        , AppMesh
        , makeColor
        , makeCube
        , makeCylinder
        , cubesIndices
        )
import Munsell exposing (ColorDict, hueRange, chromaRange, valueRange)


---- CONSTANTS ----


cubeSize : Float
cubeSize =
    40


sceneSize : Float
sceneSize =
    280


cubeScaledSize : Float
cubeScaledSize =
    cubeSize / sceneSize


xySpacing : Float
xySpacing =
    45 / sceneSize


zSpacing : Float
zSpacing =
    90 / sceneSize



---- HUE PAGE CUBES ----


buildMesh : ColorDict -> Int -> AppMesh
buildMesh colors hue =
    hueGridCubes colors hue
        |> toMesh


hueGridCubes : ColorDict -> Int -> List Cube
hueGridCubes colors hue =
    List.foldl (\value acc -> (hueCubesForValue colors hue value) ++ acc) [] valueRange


hueCubesForValue : ColorDict -> Int -> Int -> List Cube
hueCubesForValue colors hue value =
    List.foldl
        (\chroma acc ->
            case hueCube colors hue value chroma of
                Just rect ->
                    rect :: acc

                Nothing ->
                    acc
        )
        []
        chromaRange


hueCube : ColorDict -> Int -> Int -> Int -> Maybe Cube
hueCube colors hue value chroma =
    case makeColor colors hue value chroma of
        Just color ->
            xfHueCube hue value chroma
                |> makeCube color
                |> Just

        Nothing ->
            Nothing


xfHueCube : Int -> Int -> Int -> Mat4
xfHueCube _ value chroma =
    let
        x =
            ((toFloat (chroma // 2)) - 4) * xySpacing

        y =
            ((toFloat value) - 5) * xySpacing
    in
        Mat4.identity
            |> scale (vec3 cubeScaledSize cubeScaledSize cubeScaledSize)
            |> translate (vec3 x y 0)


toMesh : List Cube -> AppMesh
toMesh cubes =
    WebGL.indexedTriangles (List.concat cubes) (cubesIndices 0 cubes)
