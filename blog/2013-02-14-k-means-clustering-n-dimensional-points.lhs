---
layout: post
title: "K-Means Clustering N-Dimensional Points"
date: 2013-02-14 16:12
author: Ranjit Jhala
published: false 
comments: true
external-url:
categories: basic measures 
demo: kmeans.hs
---

[Last time][safeList] we introduced a new specification called a 
*measure* and demonstrated how to use it to encode the *length* 
of a list, and thereby verify that functions like `head` and `tail` 
were only called with non-empty lists (whose length was *strictly* 
greater than `0`.) As several folks pointed out, once LiquidHaskell 
can reason about lengths, it can do a lot more than just analyze
non-emptiness. 

Indeed! 

So today, let me show you how one might implement a k-means 
algorithm that clusters `n`-dimensional points into at most 
k groups, and how LiquidHaskell can help us write and enforce 
these size requirements. 

<!-- For example, XXX pointed out that we can use the type
system to give an *upper bound* on the size of a list (e.g. 
using a gigantic `MAX_INT` value as a proxy for finite lists.) 
-->

<!-- more -->

{- |
Module      :  Data.KMeans
Copyright   :  (c) Keegan Carruthers-Smith, 2009
License     :  BSD 3 Clause
Maintainer  :  gershomb@gmail.com
Stability   :  experimental

A simple implementation of the standard k-means clustering algorithm: <http://en.wikipedia.org/wiki/K-means_clustering>. K-means clustering partitions points into clusters, with each point belonging to the cluster with th nearest mean. As the general problem is NP hard, the standard algorithm, which is relatively rapid, is heuristic and not guaranteed to converge to a global optimum. Varying the input order, from which the initial clusters are generated, can yield different results. For degenerate and malicious cases, the algorithm may take exponential time.

-}

{-# LANGUAGE ScopedTypeVariables, TypeSynonymInstances, FlexibleInstances #-}

module Data.KMeans (kmeans, kmeansGen)
    where

-- import Data.List (transpose, sort, groupBy, minimumBy)
import Data.List (sort, span, minimumBy)
import Data.Function (on)
import Data.Ord (comparing)
import Language.Haskell.Liquid.Prelude (liquidAssert, liquidError)

-- Liquid: Kept for exposition, can use Data.List.groupBy
{-@ assert groupBy :: (a -> a -> Bool) -> [a] -> [{v:[a] | len(v) > 0}] @-}
groupBy                 :: (a -> a -> Bool) -> [a] -> [[a]]
groupBy _  []           =  []
groupBy eq (x:xs)       =  (x:ys) : groupBy eq zs
                           where (ys,zs) = span (eq x) xs

{-@ assert transpose :: n:Int
                     -> m:{v:Int | v > 0} 
                     -> {v:[{v:[a] | len(v) = n}] | len(v) = m} 
                     -> {v:[{v:[a] | len(v) = m}] | len(v) = n} 
  @-}

transpose :: Int -> Int -> [[a]] -> [[a]]
transpose 0 _ _              = []
transpose n m ((x:xs) : xss) = (x : map head xss) : transpose (n - 1) m (xs : map tail xss)
transpose n m ([] : _)       = liquidError "transpose1" 
transpose n m []             = liquidError "transpose2"

data WrapType b a = WrapType {getVect :: b, getVal :: a}

instance Eq (WrapType [Double] a) where
   (==) = (==) `on` getVect

instance Ord (WrapType [Double] a) where
    compare = comparing getVect

-- dist ::  [Double] -> [Double] -> Double 
dist a b = sqrt . sum $ zipWith (\x y-> (x-y) ^ 2) a b      -- Liquid: zipWith dimensions

centroid n points = map (( / l) . sum) points'              -- Liquid: Divide By Zero
    where l = fromIntegral $ liquidAssert (m > 0) m
          m = length points 
          points' = transpose n m (map getVect points)

closest (n :: Int) points point = minimumBy (comparing $ dist point) points

recluster' n centroids points = map (map snd) $ groupBy ((==) `on` fst) reclustered
    where reclustered = sort [(closest n centroids (getVect a), a) | a <- points]

recluster n clusters = recluster' n centroids $ concat clusters
    where centroids = map (centroid n) clusters

--part :: (Eq a) => Int -> [a] -> [[a]]
--part x ys
--     | zs' == [] = [zs]
--     | otherwise = zs : part x zs'
--    where (zs, zs') = splitAt x ys

{-@ assert part :: n:{v:Int | v > 0} -> [a] -> [{v:[a] | len(v) > 0}] @-}
part n []       = []
part n ys@(_:_) = zs : part n zs' 
                  where zs  = take n ys
                        zs' = drop n ys

-- | Recluster points
kmeans'' n clusters
    | clusters == clusters' = clusters
    | otherwise             = kmeans'' n clusters'
    where clusters' = recluster n clusters

kmeans' n k points = kmeans'' n $ part l points
    where l = max 1 ((length points + k - 1) `div` k)

-- | Cluster points in a Euclidian space, represented as lists of Doubles, into at most k clusters.
-- The initial clusters are chosen arbitrarily.
{-@ assert kmeans :: n: Int -> k:Int -> points:[{v:[Double] | len(v) = n}] -> [[{ v: [Double] | len(v) = n}]] @-}
kmeans :: Int -> Int -> [[Double]] -> [[[Double]]]
kmeans n = kmeansGen n id

-- | A generalized kmeans function. This function operates not on points, but an arbitrary type which may be projected into a Euclidian space. Since the projection may be chosen freely, this allows for weighting dimensions to different degrees, etc.
{-@ assert kmeansGen :: n: Int -> f:(a -> {v:[Double] | len(v) = n }) -> k:Int -> points:[a] -> [[a]] @-}
kmeansGen :: Int -> (a -> [Double]) -> Int -> [a] -> [[a]]
kmeansGen n f k points = map (map getVal) . kmeans' n k . map (\x -> WrapType (f x) x) $ points















\begin{code}
module ListLengths where

import Prelude hiding (length, map, filter, head, tail, foldl1)
import Language.Haskell.Liquid.Prelude (liquidError)
import qualified Data.HashMap.Strict as M
import Data.Hashable 
\end{code}

Measuring the Length of a List
------------------------------

To begin, we need some instrument by which to measure the length of a list.
To this end, let's introduce a new mechanism called **measures** which 
define auxiliary (or so-called **ghost**) properties of data values.
These properties are useful for specification and verification, but
**don't actually exist at run-time**.
That is, measures will appear in specifications but *never* inside code.




\begin{code} Let's reuse this mechanism, this time, providing a [definition](https://github.com/ucsd-progsys/liquidhaskell/blob/master/include/GHC/Base.spec) for the measure
measure len :: forall a. [a] -> GHC.Types.Int
len ([])     = 0
len (y:ys)   = 1 + (len ys) 
\end{code}

The description of `len` above should be quite easy to follow. Underneath the 
covers, LiquidHaskell transforms the above description into refined versions 
of the types for the constructors `(:)` and `[]`,
\begin{code}Something like 
data [a] where 
  []  :: forall a. {v: [a] | (len v) = 0 }
  (:) :: forall a. y:a -> ys:[a] -> {v: [a] | (len v) = 1 + (len ys) } 
\end{code}

To appreciate this, note that we can now check that

\begin{code}
{-@ xs :: {v:[String] | (len v) = 1 } @-}
xs = "dog" : []

{-@ ys :: {v:[String] | (len v) = 2 } @-}
ys = ["cat", "dog"]

{-@ zs :: {v:[String] | (len v) = 3 } @-}
zs = "hippo" : ys
\end{code}

Dually, when we *de-construct* the lists, LiquidHaskell is able to relate
the type of the outer list with its constituents. For example,

\begin{code}
{-@ zs' :: {v:[String] | (len v) = 2 } @-}
zs' = case zs of 
        h : t -> t
\end{code}

Here, from the use of the `:` in the pattern, LiquidHaskell can determine
that `(len zs) = 1 + (len t)`; by combining this fact with the nugget
that `(len zs) = 3` LiquidHaskell concludes that `t`, and hence, `zs'`
contains two elements.

Reasoning about Lengths
-----------------------

Let's flex our new vocabulary by uttering types that describe the
behavior of the usual list functions. 

First up: a version of the [standard][ghclist] 
`length` function, slightly simplified for exposition.

\begin{code}
{-@ length :: xs:[a] -> {v: Int | v = (len xs)} @-}
length :: [a] -> Int
length []     = 0
length (x:xs) = 1 + length xs
\end{code}

**Note:** Recall that `measure` values don't actually exist at run-time.
However, functions like `length` are useful in that they allow us to
effectively *pull* or *materialize* the ghost values from the refinement
world into the actual code world (since the value returned by `length` is
logically equal to the `len` of the input list.)

Similarly, we can speak and have confirmed, the types for the usual
list-manipulators like

\begin{code}
{-@ map      :: (a -> b) -> xs:[a] -> {v:[b] | (len v) = (len xs)} @-}
map _ []     = [] 
map f (x:xs) = (f x) : (map f xs)
\end{code}

and

\begin{code}
{-@ filter :: (a -> Bool) -> xs:[a] -> {v:[a] | (len v) <= (len xs)} @-}
filter _ []     = []
filter f (x:xs) 
  | f x         = x : filter f xs
  | otherwise   = filter f xs
\end{code}

and, since doubtless you are wondering,

\begin{code}
{-@ append :: xs:[a] -> ys:[a] -> {v:[a] | (len v) = (len xs) + (len ys)} @-}
append [] ys     = ys 
append (x:xs) ys = x : append xs ys
\end{code}

We will return to the above at some later date. Right now, let's look at
some interesting programs that LiquidHaskell can prove safe, by reasoning
about the size of various lists.



Example 1: Safely Catching A List by Its Tail (or Head) 
-------------------------------------------------------

Now, let's see how we can use these new incantations to banish, forever,
certain irritating kinds of errors. 
\begin{code}Recall how we always summon functions like `head` and `tail` with a degree of trepidation, unsure whether the arguments are empty, which will awaken certain beasts
Prelude> head []
*** Exception: Prelude.head: empty list
\end{code}

LiquidHaskell allows us to use these functions with 
confidence and surety! First off, let's define a predicate
alias that describes non-empty lists:

\begin{code}
{-@ predicate NonNull X = ((len X) > 0) @-}
\end{code}

Now, we can type the potentially dangerous `head` as:

\begin{code}
{-@ head   :: {v:[a] | (NonNull v)} -> a @-}
head (x:_) = x
head []    = liquidError "Fear not! 'twill ne'er come to pass"
\end{code}

As with the case of [divide-by-zero][ref101], LiquidHaskell deduces that
the second equation is *dead code* since the precondition (input) type
states that the length of the input is strictly positive, which *precludes*
the case where the parameter is `[]`.

Similarly, we can write

\begin{code}
{-@ tail :: {v:[a] | (NonNull v)} -> [a] @-}
tail (_:xs) = xs
tail []     = liquidError "Relaxeth! this too shall ne'er be"
\end{code}

Once again, LiquidHaskell will use the precondition to verify that the 
`liquidError` is never invoked. 

Let's use the above to write a function that eliminates stuttering, that
is which converts `"ssstringssss liiiiiike thisss"` to `"strings like this"`.

\begin{code}
{-@ eliminateStutter :: (Eq a) => [a] -> [a] @-}
eliminateStutter xs = map head $ groupEq xs 
\end{code}

The heavy lifting is done by `groupEq`

\begin{code}
groupEq []     = []
groupEq (x:xs) = (x:ys) : groupEq zs
                 where (ys,zs) = span (x ==) xs
\end{code}

which gathers consecutive equal elements in the list into a single list.
By using the fact that *each element* in the output returned by 
`groupEq` is in fact of the form `x:ys`, LiquidHaskell infers that
`groupEq` returns a *list of non-empty lists*. 
(Hover over the `groupEq` identifier in the code above to see this.)
Next, by automatically instantiating the type parameter for the `map` 
in `eliminateStutter` to `(len v) > 0` LiquidHaskell deduces `head` 
is only called on non-empty lists, thereby verifying the safety of 
`eliminateStutter`. (Hover your mouse over `map` above to see the
instantiated type for it!)

Example 2: Risers 
-----------------

The above examples of `head` and `tail` are simple, but non-empty lists pop
up in many places, and it is rather convenient to have the type system
track non-emptiness without having to make up special types. Let's look at a
more interesting example, popularized by [Neil Mitchell][risersMitchell]
which is a key step in an efficient sorting procedure, which we may return
to in the future when we discuss sorting algorithms.

\begin{code}
risers           :: (Ord a) => [a] -> [[a]]
risers []        = []
risers [x]       = [[x]]
risers (x:y:etc) = if x <= y then (x:s):ss else [x]:(s:ss)
    where 
      (s, ss)    = safeSplit $ risers (y:etc)
\end{code}

The bit that should cause some worry is `safeSplit` which 
simply returns the `head` and `tail` of its input, if they
exist, and otherwise, crashes and burns

\begin{code}
safeSplit (x:xs)  = (x, xs)
safeSplit _       = liquidError "don't worry, be happy"
\end{code}

How can we verify that `safeSplit` *will not crash* ?

The matter is complicated by the fact that since `risers` 
*does* sometimes return an empty list, we cannot blithely 
specify that its output type has a `NonNull` refinement.

Once again, logic rides to our rescue!

The crucial property upon which the safety of `risers` rests
is that when the input list is non-empty, the output list 
returned by risers is *also* non-empty. It is quite easy to clue 
LiquidHaskell in on this, namely through a type specification:

\begin{code}
{-@ risers :: (Ord a) 
           => zs:[a] 
           -> {v: [[a]] | ((NonNull zs) => (NonNull v)) } @-} 
\end{code}

Note how we relate the output's non-emptiness to the input's
non-emptiness,through the (dependent) refinement type. With this 
specification in place, LiquidHaskell is pleased to verify `risers` 
(i.e. the call to `safeSplit`).

Example 3: MapReduce 
--------------------

Here's a longer example that illustrates this: a toy *map-reduce* implementation.

First, let's write a function `keyMap` that expands a list of inputs into a 
list of key-value pairs:

\begin{code}
keyMap :: (a -> [(k, v)]) -> [a] -> [(k, v)]
keyMap f xs = concatMap f xs
\end{code}

Next, let's write a function `group` that gathers the key-value pairs into a
`Map` from *keys* to the lists of values with that same key.

\begin{code}
group kvs = foldr (\(k, v) m -> inserts k v m) M.empty kvs 
\end{code}

The function `inserts` simply adds the new value `v` to the list of 
previously known values `lookupDefault [] k m` for the key `k`.

\begin{code}
inserts k v m = M.insert k (v : vs) m 
  where vs    = M.lookupDefault [] k m
\end{code}

Finally, a function that *reduces* the list of values for a given
key in the table to a single value:

\begin{code}
reduce    :: (v -> v -> v) -> M.HashMap k [v] -> M.HashMap k v
reduce op = M.map (foldl1 op)
\end{code}

where `foldl1` is a [left-fold over *non-empty* lists][foldl1]

\begin{code}
{-@ foldl1      :: (a -> a -> a) -> {v:[a] | (NonNull v)} -> a @-}
foldl1 f (x:xs) =  foldl f x xs
foldl1 _ []     =  liquidError "will. never. happen."
\end{code}

We can put the whole thing together to write a (*very*) simple *Map-Reduce* library

\begin{code}
mapReduce   :: (Eq k, Hashable k) 
                => (a -> [(k, v)]) -- ^ key-mapper
                -> (v -> v -> v)   -- ^ reduction operator
                -> [a]             -- ^ inputs
                -> [(k, v)]        -- ^ output key-values

mapReduce f op  = M.toList 
                . reduce op 
                . group 
                . keyMap f
\end{code}

Now, if we want to compute the frequency of `Char` in a given list of words, we can write:

\begin{code}
{-@ charFrequency :: [String] -> [(Char, Int)] @-}
charFrequency     :: [String] -> [(Char, Int)]
charFrequency     = mapReduce wordChars (+)
  where wordChars = map (\c -> (c, 1)) 
\end{code}

You can take it out for a spin like so:

\begin{code}
f0 = charFrequency [ "the", "quick" , "brown"
                   , "fox", "jumped", "over"
                   , "the", "lazy"  , "cow"   ]
\end{code}

**Look Ma! No Types:** LiquidHaskell will gobble the whole thing up, and
verify that none of the undesirable `liquidError` calls are triggered. By
the way, notice that we didn't write down any types for `mapReduce` and
friends.  The main invariant, from which safety follows is that the `Map`
returned by the `group` function binds each key to a *non-empty* list of
values.  LiquidHaskell deduces this invariant by inferring suitable types
for `group`, `inserts`, `foldl1` and `reduce`, thereby relieving us of that
tedium. In short, by riding on the broad and high shoulders of SMT and
abstract interpretation, LiquidHaskell makes a little typing go a long way. 


Conclusions
-----------

1. How to do *K-Means Clustering* !

2. Track precise length properties with **measures**

3. Circumvent limitations of SMT with a touch of **dynamic** checking using **assumes**


[vecbounds]:  /blog/2013/01/05/bounding-vectors.lhs/ 
[ghclist]:    https://github.com/ucsd-progsys/liquidhaskell/blob/master/include/GHC/List.lhs#L125
[foldl1]:     http://hackage.haskell.org/packages/archive/base/latest/doc/html/src/Data-List.html#foldl1
[safeList]:   /blog/2013/01/31/safely-catching-a-list-by-its-tail.lhs/ 



