# DHT Chord protocol

<b>Team members </b> \
Shashank Mayekar, Tanya Pathak

<b>Working</b> \
We have been able to initialize the chord network with the given number of nodes and for the given requests. The chord is able to create the nodes and the keys using SHA1. \
The ‘m’ we are using is 128 which is the original hash from SHA1, where we hash the integer 1 to nunmNodes. \
Each node is able to successfully request for all the requests (keys) in the network, using findSuccessor() and closestPrecedingNode() methods as part of the Chord API. \
After summing the number of hops for each request for each node, we have averaged it. \
\
<b>Tested with:</b> \
Number of requests (i.e. numNodes * numRequests) for which we could compute the average is 5000. \

<b>To run </b> \
mix escript.build \
Escript proj3new 200 5
