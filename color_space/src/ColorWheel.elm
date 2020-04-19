module ColorWheel exposing (sceneRadius, wheel)

import Angle exposing (Angle)
import Axis3d
import Color exposing (Color)
import Dict exposing (Dict)
import Length exposing (Length)
import Munsell exposing (ColorDict)
import Point3d
import Scene3d
import Vector3d
import World exposing (WorldEntity, WorldEntityList)



---- CONSTANTS ----
{- All these are measured in centimeters. -}


cylinderRadius : Float
cylinderRadius =
    60


cubeSize : Float
cubeSize =
    40


r0 : Float
r0 =
    cylinderRadius + cubeSize + 20


rSpacing : Float
rSpacing =
    50


zSpacing : Float
zSpacing =
    90


zForValue : Int -> Float
zForValue value =
    toFloat (value - 5) * zSpacing


sceneRadius : Float
sceneRadius =
    r0 + (8 * rSpacing) + cubeSize



---- ENTITIES: MUNSELL COLOR WHEEL CYLINDERS AND CUBES


wheel : ColorDict -> Dict Int WorldEntityList
wheel colors =
    Munsell.valueRange
        |> List.map (\value -> ( value, entitiesForValue colors value ))
        |> Dict.fromList


entitiesForValue : ColorDict -> Int -> WorldEntityList
entitiesForValue colors value =
    let
        cylinder =
            cylinderForValue value

        cubes =
            cubesForValue colors value
    in
    cylinder :: cubes


cylinderForValue : Int -> WorldEntity
cylinderForValue value =
    let
        z =
            zForValue value

        origin =
            Point3d.centimeters 0 0 z

        color =
            Munsell.neutralColor value
    in
    World.matteCylinderAt origin
        { radius = Length.centimeters cylinderRadius
        , length = Length.centimeters cubeSize
        }
        color


cubesForValue : ColorDict -> Int -> WorldEntityList
cubesForValue colors value =
    Munsell.hueRange
        |> List.foldl (\hue acc -> cubesForHV colors hue value ++ acc) []


cubesForHV : ColorDict -> Int -> Int -> WorldEntityList
cubesForHV colors hue value =
    Munsell.chromaRange
        |> List.foldl
            (\chroma acc ->
                case cubeInGamut colors hue value chroma of
                    Just cube ->
                        cube :: acc

                    Nothing ->
                        acc
            )
            []


cubeInGamut : ColorDict -> Int -> Int -> Int -> Maybe WorldEntity
cubeInGamut colors hue value chroma =
    case Munsell.findColor colors hue value chroma of
        Just { color } ->
            Just (cubeWithColor color hue value chroma)

        Nothing ->
            Nothing


cubeWithColor : Color -> Int -> Int -> Int -> WorldEntity
cubeWithColor color hue value chroma =
    let
        scaledSize =
            scaleCube hue value chroma cubeSize

        theta =
            toFloat hue * 360.0 / 1000.0

        band =
            (chroma // 2) - 1

        x =
            r0 + (toFloat band * rSpacing)

        z =
            zForValue value

        origin =
            Point3d.centimeters x 0 z
    in
    World.matteCubeAt origin scaledSize color
        |> Scene3d.rotateAround Axis3d.z (Angle.degrees theta)


scaleCube : Int -> Int -> Int -> Float -> Length
scaleCube _ _ chroma size =
    let
        x =
            case chroma of
                2 ->
                    0.35

                4 ->
                    0.5

                6 ->
                    0.7

                8 ->
                    0.9

                14 ->
                    1.4

                16 ->
                    1.4

                _ ->
                    1
    in
    Length.centimeters (x * size)
