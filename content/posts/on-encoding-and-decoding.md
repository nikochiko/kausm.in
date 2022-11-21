---
title: "On Encoding and Decoding"
date: 2022-11-21T23:05:31+05:30
draft: false
math: true
---

I was in the shower and got thinking about how computers encode everything as numbers.

Around the time when I was in school and had some familiarity with programming, I didn't really think it was a good analogy to think of computers as sophisticated calculators. Calculators are dumb, they can only perform operations on numbers whereas computers are able to build something as complicated as the internet.

I was younger then. Now I am older and wiser and I can see why “computers are sophisticated calculators” and even appreciate the beauty of what it implies.

To a younger me, I would explain the idea like this:

> Padawan, you need to understand that computers are the epitome of applied mathematics.  
> Why, you ask? Look around you. Everything you perceive, you can represent as math. Colors, bodies, collisions, and even movements.
> 
> You don't believe me? Take the movement of a falling box. Can you represent this as math?  
> You can say there's a box that is 1m by height, width, and length. It is in free fall and its current velocity is 20 m/s. Acceleration due to gravity should be assumed to be 10 m/s2.
> 
> Now I tell you, you can represent that with math as 1112010. You see? I just put all the numbers together with the assumption that m, m/s, and m/s2 are our units. The first three digits are height, width, and length; in that order. Then there are two digits for current velocity, and two digits for the acceleration.
> 
> Now if I give you a different sequence, let's say 2343010, and tell you that this also represents a falling box in a similar way, will you be able to recreate the scenario?  
> Good work, Padawan. Of course it is an unusually shaped large box with dimensions 2x3x4 in m. Its current velocity is 30 m/s and acceleration due to gravity is 10 m/s2.

That is much closer to what a calculator does. These are numbers and we can combine them as we want. If we were asked to find out the time to collision if the two hypothetical boxes were thrown one after the other, we could do that with a calculator.

If the calculator is powerful enough, we can write the procedure once and use it multiple times with different values. Computer enough for you?

> Not yet? No? Ah, you're not convinced how I would teach a computer to understand and answer questions such as the one about collision. Good question.

It's the same, really. No different, except the computer now understands something different. It will be easier to explain if we put words to what we did: we first _encoded_ the motion of a box into a sequence of digits. We know how to _decode_ it, but we now need to teach a computer that.

Once again, we will encode. This time, we will encode the _procedure of decoding_ this falling-box format, and then the procedure for finding the collision time.

```text-plain
010 111 212 323 524
```

This is my encoding. Each group of three has 3 digits. First digit represents the starting position in the sequence (starting from leftmost digit as 0th position), second digit represents the number of digits that need to be taken (notice it is 2 for the last 2 groups, for acceleration and velocity), and the third is its reference number. The reference number will allow us to use these quantities as variables.

This first part of the procedure decodes the data into variables. Now let's solve the collision problem. The slower box is dropped first, and the faster box is dropped later. We will ignore the dimensions of the boxes in our calculations.

If you do the math, you'll arrive at the result that the time to collision would be:

\\(u\_1t + \\frac{1}{2}a\_1t^2 = u\_2t + \\frac{1}{2}a\_2t^2\\)

\\(2 \*(u\_1-u\_2) + (a\_1-a\_2)\*t = 0\\)

\\(t = 2 \* \\frac{(u\_2 - u\_1)}{a\_1 - a\_2}\\)

Let's say this is the encoding for our math language that the computer understands this notation:

*   Operations:
    *   000 - addition
    *   001 - subtraction
    *   002 - multiplication
    *   003 - division
    *   004 - parenthesis open
    *   005 - parenthesis close
*   Operands:
    *   1xx - with xx being a variable ID
    *   2xx - with xx being a constant number as decimal

We can encode the above equation as:

```text-plain
222 002 004 113 001 103 005 003 004 104 001 114 005
 2   *   (   u2  -   u1  )   /   (   a1  -   a2  )
```

That's how you would represent a procedure as data, in the form of sequences of digits.

Computers only understand bits because they communicate with base 2 numbers. The same ideas are applicable when they are converted from base10 to base2.

Appreciation
------------

Isn't it wonderful that with such simple ideas of encoding and decoding we have today been able to invent things such as the internet?  
We have been able to use numbers to encode our words and social interactions so that they can be shipped to remote places and decoded there. It blows my mind.

