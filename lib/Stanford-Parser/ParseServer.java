import java.io.*;
import java.net.*;
import java.util.Collection;
import java.util.List;
import java.io.StringReader;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.charset.Charset;
import java.nio.file.*;
import java.io.BufferedWriter;
import java.util.Set;
import java.util.HashSet;
import java.nio.file.StandardOpenOption;
import java.lang.StringBuilder;
import java.util.Collections;
import java.util.ArrayList;
import java.util.Date;

import edu.stanford.nlp.process.TokenizerFactory;
import edu.stanford.nlp.process.CoreLabelTokenFactory;
import edu.stanford.nlp.process.DocumentPreprocessor;
import edu.stanford.nlp.process.PTBTokenizer;
import edu.stanford.nlp.ling.CoreLabel;
import edu.stanford.nlp.ling.HasWord;
import edu.stanford.nlp.ling.Sentence;
import edu.stanford.nlp.trees.*;
import edu.stanford.nlp.parser.lexparser.LexicalizedParser;
import java.lang.reflect.*;
import edu.stanford.nlp.semgraph.*;
import edu.stanford.nlp.ling.IndexedWord;
import edu.stanford.nlp.util.Generics;

import org.json.simple.JSONObject;
import org.json.simple.JSONValue;
import org.json.simple.JSONArray;

class ParseServer {
    public static void main(String argv[]) throws Exception {

        // Lets first print the date
        Date date = new Date();
        System.out.println(date.toString());

        // Initialize the server
        String fromclient;
        String toclient;
        ServerSocket Server = new ServerSocket (5000);
        System.out.println ("TCPServer Waiting for client on port 5000");
        Socket connected = Server.accept();
        System.out.println( "THE CLIENT "+
            connected.getInetAddress() +":"+connected.getPort()+" IS CONNECTED ");
        BufferedReader inFromUser = new BufferedReader(new InputStreamReader(System.in));
        BufferedReader inFromClient = new BufferedReader(new InputStreamReader (connected.getInputStream()));
        PrintWriter outToClient = new PrintWriter(connected.getOutputStream(),true);
        outToClient.println("Connection established");
        fromclient = inFromClient.readLine();
        if (!fromclient.equals("Load Parser")) {
            outToClient.println("ERROR: Not the right command");
            connected.close();
        }
        else {
            try {
                LexicalizedParser lp = LexicalizedParser.loadModel("edu/stanford/nlp/models/lexparser/englishPCFG.ser.gz");
                TreebankLanguagePack tlp = new PennTreebankLanguagePack();
                GrammaticalStructureFactory gsf = tlp.grammaticalStructureFactory();
                outToClient.println("Parser Loaded...Ready to accept sentences...");
                System.out.println("Parser Loaded...Ready to accept sentences...");
                while ( true ) {
                    fromclient = inFromClient.readLine();
                    if ( fromclient.equals("q") || fromclient.equals("Q") ) {
                        System.out.println("Client wants to quit.");
                        connected.close();
                        break;
                    }
                    else {
                        System.out.println( "RECIEVED :" + fromclient );
                    }
                    StringBuilder output = new StringBuilder();
                    Reader reader = new StringReader(fromclient);
                    for (List<HasWord> sentence : new DocumentPreprocessor(reader)) {
                        Tree parse = lp.apply(sentence);
                        GrammaticalStructure gs = gsf.newGrammaticalStructure(parse);
                        Collection<TypedDependency> tdl = gs.typedDependenciesCCprocessed();
                        SemanticGraph graph = new SemanticGraph(tdl);
                        output.append(serialize(graph));
                        output.append("\n");
                    }
                    toclient = output.toString();
                    outToClient.println(toclient);
                }
            } catch (Exception e) {
                outToClient.println("ERROR: Couldnt load parser. \n" + e);
                connected.close();
                System.exit(0);
            }
        }
        System.out.println("Client serviced. Going down gracefully.");
        connected.close();
    }

    public static String serialize(SemanticGraph graph) {
        Collection<IndexedWord> rootNodes = graph.getRoots();
        if (rootNodes.isEmpty()) {
            // Shouldn't happen, but return something!
            return("No Tree Found");
        }

        JSONObject parsetree = new JSONObject();
        JSONArray rootlist = new JSONArray();
        Set<IndexedWord> used = Generics.newHashSet();
        for (IndexedWord root : rootNodes) {
            JSONObject cur_root = new JSONObject();
            cur_root.put("level", new Integer(0));
            cur_root.put("word", root.word());
            cur_root.put("pos", root.tag());
            cur_root.put("dep", "root");
            recSerialize(graph, root, 1, used, cur_root);
            rootlist.add(cur_root);
        }
        parsetree.put("parse", rootlist);

        Set<IndexedWord> nodes = Generics.newHashSet(graph.vertexSet());
        nodes.removeAll(used);
        if (!nodes.isEmpty()) {
            JSONArray orphans = new JSONArray();
            while (!nodes.isEmpty()) {
                IndexedWord node = nodes.iterator().next();
                JSONObject orphan = new JSONObject();
                orphan.put("level", new Integer(0));
                orphan.put("word", node.word());
                orphan.put("pos", node.tag());
                orphan.put("dep", "root");
                recSerialize(graph, node, 1, used, orphan);
                nodes.removeAll(used);
            }
            parsetree.put("orphans", orphans);
        }
        try {
            StringWriter out = new StringWriter();
            parsetree.writeJSONString(out);
            String jsonText = out.toString();
            return jsonText;
        } catch (IOException ioe) {
          System.out.println("Could use StringWriter for JSON string conversion.");
          return JSONValue.toJSONString(parsetree);
        }
    }

    // helper for serialize()
    private static void recSerialize(SemanticGraph graph, IndexedWord curr, int offset, Set<IndexedWord> used, JSONObject cur_node) {
        used.add(curr);
        List<SemanticGraphEdge> edges = graph.outgoingEdgeList(curr);
        Collections.sort(edges);
        if (!edges.isEmpty()){
            JSONArray children = new JSONArray();
            for (SemanticGraphEdge edge : edges) {
                JSONObject child = new JSONObject();
                IndexedWord target = edge.getTarget();
                child.put("level", new Integer(offset));
                child.put("word", target.word());
                child.put("pos", target.tag());
                child.put("dep", edge.getRelation().toString());
                if (!used.contains(target)) {
                    recSerialize(graph, target, offset + 1, used, child);
                }
                children.add(child);
            }
            cur_node.put("children", children);
        }
    }

    private static String space(int width) {
        StringBuilder b = new StringBuilder();
        for (int i = 0; i < width; i++) {
            b.append(' ');
        }
        return b.toString();
    }
}
