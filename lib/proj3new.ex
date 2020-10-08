defmodule Proj3new do
  use GenServer

  def getNumNodes(pid) do
    GenServer.call(pid, {:getNumNodes})
  end

  def handle_call({:getNumNodes}, _from, state) do
    {numNodes, numRequests} = state
    {:reply, numNodes, state}
  end 

  def getNumRequests(pid) do
    GenServer.call(pid, {:getNumRequests})
  end

  def handle_call({:getNumRequests}, _from, state) do
    {numNodes, numRequests} = state
    {:reply, numRequests, state}
  end 

  def init(args) do
    if (Enum.count(args) != 2) do
      IO.puts("Enter 2 integers: numNodes & numRequests")
      System.halt(1)
    end
    numNodes = Enum.at(args,0) |> String.to_integer
    numRequests = Enum.at(args,1) |> String.to_integer
    {:ok, {numNodes, numRequests}}
  end

  def createNodeMap(map, numNodes, uniqNums) do
    #IO.inspect uniqNums
    if map_size(map) == numNodes do
      map
    else
      rNum = Enum.random(uniqNums)
      uniqNums = uniqNums  -- [rNum]
      {:ok, nodePid} = Proj3new.Node.start_link(rNum)
      newMap = Map.put(map, rNum, nodePid)
      createNodeMap(newMap, numNodes, uniqNums)
    end

  end

  def createKeyList(list, numRequests, uniqNums) do
    if Enum.count(list) == numRequests do
      list
      #IO.inspect list
    else
      rNum = Enum.random(uniqNums)
      uniqNums = uniqNums  -- [rNum]
      newList = list ++ [rNum]
      createKeyList(newList, numRequests, uniqNums)
    end

  end

  def main(args) do
    
    {:ok, mainActorPID} = GenServer.start_link(__MODULE__, args, [])
    numNodes = Enum.at(args,0) |> String.to_integer
    numRequests = Enum.at(args,1) |> String.to_integer

    #Enum.each(1..numNodes, fn(i) -> IO.inspect i end)
    # nodePidList = Enum.map(1..numNodes, fn(i) ->
    #   {:ok, nodePid} = Proj3new.Node.start_link(-1)
    #   {nodePid}
    # end)
    


    fnGenNodeList = fn(x) ->
      origHash = :crypto.hash(:sha, Integer.to_string(x)) |> Base.encode16 |> Convertat.from_base(16) |> Convertat.to_base(2)#|>String.slice(0..7)
      shortHash = origHash |> Convertat.from_base(2) |> Convertat.to_base(10)
      {hashInt, ""} = Integer.parse(shortHash)
      {:ok, nodePid} = Proj3new.Node.start_link(hashInt)
      {hashInt, nodePid}
    end
    nodeMap = Map.new Enum.map(1..numNodes, fnGenNodeList)
    
    twoM = trunc(Float.floor(:math.pow(2,160)))
    # uniqNums = Enum.to_list(1..twoM)
    # nodeMap = Map.new createNodeMap(%{}, numNodes, uniqNums)
    # keyList = createKeyList([], numRequests, uniqNums)
    keyList = Enum.map(1..numRequests, fn(x) -> :rand.uniform(twoM) end)

    #IO.inspect keyList

    #IO.inspect nodeMap
    sortedNodeList = Map.to_list(nodeMap)
    #IO.inspect sortedNodeList
    #IO.inspect Enum.count(sortedNodeList)
    fnSetSP = fn(i) ->
      {currHash, currNodePid} = Enum.at(sortedNodeList, i)
      {prevHash, prevNodePid} = Enum.at(sortedNodeList, i-1)
      {nextHash, nextNodePid} = Enum.at(sortedNodeList, i+1)
      Proj3new.Node.setSuccessor(currNodePid, nextHash)
      Proj3new.Node.setPredecessor(currNodePid, {prevHash, prevNodePid})
    end
    Enum.each(0..numNodes-2, fnSetSP)
    
    {lastHash, lastNodePid} = Enum.at(sortedNodeList, numNodes-1)
    {firstHash, firstNodePid} = Enum.at(sortedNodeList, 0)
    Proj3new.Node.setSuccessor(lastNodePid, firstHash)

    # print = fn(x) ->
    #   {nodeNum, nodePid} = x
    #   succ = Proj3new.Node.getSuccessor(nodePid)
    #   IO.inspect {nodeNum, succ}
    # end
    # Enum.each(sortedNodeList, print)
    
    setFingerTable = fn(pid) ->
      nodeHashList = Map.keys(nodeMap)
      n = Proj3new.Node.getHash(pid)
      findHash = fn(k) ->
        kIndex = rem(n + trunc(Float.floor(:math.pow(2,k-1))), trunc(Float.floor(:math.pow(2,160))))
        kVal = Enum.max_by(nodeHashList, fn(hash) -> hash >= kIndex end) 
        #IO.inspect {kIndex, kVal}
        if kVal == Proj3new.Node.getHash(pid) do
          #IO.inspect {Proj3new.Node.getHash(pid), kVal}
          #System.halt(0)
        end
        {kVal, Map.get(nodeMap, kVal)}
      end
      fingerTable =
      Enum.map(1..160, findHash)
      Proj3new.Node.setFingerT(pid, fingerTable)
      #IO.inspect {n, fingerTable}
    end
    Enum.each(Map.values(nodeMap), setFingerTable)

    #[head|tail] = Map.values(nodeMap)
    #IO.inspect Proj3new.Node.printFT(head)
    

    # {node, count} = IO.inspect Proj3new.Node.findSuccessor(Enum.at(Map.values(nodeMap), 4), 2, numNodes, 0)
    # IO.inspect {node, count}

    #IO.inspect nodeMap

    goThroughNodes = fn(pid) ->
      goThroughKeys = fn(key) ->
        #IO.inspect {pid, key}
        {succ, count} = Proj3new.Node.findSuccessor(pid, key, twoM, 0)
        #IO.inspect {Proj3new.Node.getHash(pid), count}
        count
      end
      list = Enum.map(keyList, goThroughKeys)
      #IO.inspect list
      sum1 = Enum.reduce(list, fn(x, acc) -> x + acc end)
      IO.inspect sum1
    end
    listCount = Enum.map(Map.values(nodeMap), goThroughNodes)
    sum2 = Enum.reduce(listCount, fn(x, acc) -> x + acc end)
    
    avg = sum2/(numNodes * numRequests)
    IO.inspect avg

  end
end


defmodule Proj3new.Node do
  use GenServer

  def handle_call({:findSuccessor, findID, numNodes, count}, _from, state) do
    {hashInt, succ, pred, fingerTable} = state
    {mySucc, mySuccPid} = Enum.at(fingerTable, 0)
    #IO.inspect {findID, hashInt, succ}
    if (is_in_between_fs(hashInt, succ, findID, numNodes)) do
    #if (findID > Enum.min([hashInt, succ]) or findID <= Enum.max([hashInt, succ])) do
      #IO.inspect count
      #IO.inspect state
      {:reply, {succ, count+1}, state}
    else
      {succNode, succPid} = closestPrecedingNode(self, hashInt, succ, fingerTable, findID, numNodes)
      inspect count
      #IO.inspect {hashInt, fingerTable, findID}, label: "INSPECT"
      
      {succ, count} =
      if hashInt == succNode do
        findSuccessor(mySuccPid, findID, numNodes, count)
      else
        findSuccessor(succPid, findID, numNodes, count)
      end
       
      #IO.inspect state
      {:reply, {succ, count+1}, state}
    end
  end
  
  def is_in_between_fs(beg, en, id, neighbours) do
    if beg < en do
      id > beg and id <= en
    else
      (id > beg and id <= neighbours) or (id >= 1 and id <= en)
    end
  end

  def is_in_between_cp(beg, en, id, neighbours) do
    if beg < en do
      id > beg and id < en
    else
      (id > beg and id <= neighbours) or (id >= 1 and id < en)
    end
  end

# def recFindFt(findID, ft, index, {hashInt, self}, {final, fPid}) do
#   if index == -1 do
#     if final == 0 do
#       {hashInt, self}
#     else
#       {final, pid}
#     end
#   else
#     {currFinger, pid} = Enum.at(ft)
#     if currFinger <= findID and (index == Enum.size(ft) or currFinger >= final) do
#       {final, fPid} = {currFinger, pid}
#     end
#   end
# end

def closestPrecedingNode(self, hashInt, succ, fingerTable, findID, numNodes) do
    revFT = Enum.reverse(fingerTable)
    fnCpNode = fn(x) ->
      {currFinger, pid} = x
      if (is_in_between_fs(hashInt, findID, currFinger, numNodes)) do
      #if (findID > Enum.min([hashInt, findID]) or findID < Enum.max([hashInt, findID])) do
        {currFinger, pid}
      end
    end
    #{cpNode, cpNodePid} = recFindFt(findID, fingerTable, Enum.count(revFT)-1, {hashInt, self}, {0, nil})
    {cpNode, cpNodePid} = Enum.find(revFT, {hashInt, self}, fnCpNode)
    #IO.inspect {hashInt, succ, fingerTable, findID}, label: "in closestpredecessor = "
    {cpNode, cpNodePid}
end

  # def handle_call({:closestPrecedingNode, findID}, _from, state) do
  #   {hashInt, succ, fingerTable} = state
  #   fnCpNode = fn(x) ->
  #     {currFinger, pid} = Enum.at(fingerTable, x)
  #     if currFinger > hashInt and currFinger < findID do
  #       {currFinger, pid}
  #     end
  #   end
  #   {cpNode, cpNodePid} = Enum.find(4..1, {hashInt, self}, fnCpNode)
  #   {:reply, {cpNode, cpNodePid}, state}
  # end

  
  # def closestPrecedingNode(pid, findID) do
  #   GenServer.call(pid, {:closestPrecedingNode,findID} )
  # end

  def findSuccessor(pid, findID, numNodes, count) do
    GenServer.call(pid, {:findSuccessor, findID, numNodes, count})
  end


  def getHash(pid) do
    GenServer.call(pid, {:getHash})
  end

  def handle_call({:getHash}, _from, state) do
    {hashInt, succ, pred, ft} = state
    {:reply, hashInt, state}
  end

  def getSuccessor(pid) do
    GenServer.call(pid, {:getSuccessor})
  end

  def handle_call({:getSuccessor}, _from, state) do
    {hashInt, succ, pred, ft} = state
    {:reply, succ, state}    # returns {successorNodeNum, successorPid}
  end

  # def getPredecessor(pid) do
  #   GenServer.call(pid, {:getPredecessor})
  # end

  # def handle_call({:getPredecessor}, _from, state) do
  #   {id, hashInt, succ, pred, []} = state # returns {predecessorNodeNum, predecessorPid}
  #   {:reply, pred, state}
  # end

  def setSuccessor(pid, mySucc) do
    GenServer.cast(pid, {:setSuccessor, mySucc})
  end

  def handle_cast({:setSuccessor, mySucc}, state) do
    {hashInt, succ, pred, ft} = state
    newState = {hashInt, mySucc, pred, ft}
    {:noreply, newState}    # returns {successorNodeNum, successorPid}
  end

  def setFingerT(pid, newFt) do
    GenServer.cast(pid, {:setFingerT, newFt})
  end

  def handle_cast({:setFingerT, newFingerT}, state) do
    {hashInt, succ, pred, fingerT} = state
    newState = {hashInt, succ, pred, newFingerT}
    {:noreply, newState}    # returns {successorNodeNum, successorPid}
  end



  def setPredecessor(pid, myPred) do
    GenServer.cast(pid, {:setPredecessor, myPred})
  end

  def handle_cast({:setPredecessor, myPred}, state) do
    {hashInt, succ, pred, ft} = state
    newState = {hashInt, succ, myPred, ft}
    {:noreply, newState}    # returns {successorNodeNum, successorPid}
  end

  def printFT(pid) do
    GenServer.call(pid, {:printFT})
  end

  def handle_call({:printFT}, _from, state) do
    {hashInt, succ, pred, ft} = state
    {:reply, ft, state}
  end

  def init({:msg, hash}) do
    #{hashInt, ""} = Integer.parse(hash)
    # setFingers = fn(m) ->
    #   {rem(trunc(Float.floor(:math.pow(2,(m-1)))) + hashInt, 16), {-1, nil}}
    # end
    # fingerTable = Map.new Enum.map(1..4, setFingers)
    {:ok, {hash, hash, nil,  []}}
#         hash, succ,  pred,  fingerTable (list)
  end

  def start_link(hash) do
    GenServer.start_link(__MODULE__, {:msg, hash}, [])
  end

end