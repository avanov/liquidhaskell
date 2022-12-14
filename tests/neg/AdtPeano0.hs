{-@ LIQUID "--expect-any-error" @-}
{-@ LIQUID "--reflection" @-}

module AdtPeano0 where

data Influx = Silly Int

{-@ reflect thing @-}
thing :: Influx -> Int
thing (Silly a) = a + 1

{-@ reflect bling @-}
bling :: Influx -> Int
bling (Silly b) = b

{-@ test :: m:Influx -> { thing m = bling m} @-}
test :: Influx -> (Int, Int)
test m = (thing m, bling m)
