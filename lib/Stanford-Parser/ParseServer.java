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
                while ( true ) {
                    fromclient = inFromClient.readLine();
                    if ( fromclient.equals("q") || fromclient.equals("Q") ) {
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
                        output.append(toString(graph));
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
        connected.close();
    }

    // This takes in a Semantic graph and is only for display purposes.
    public static String toString(SemanticGraph graph) {
        Collection<IndexedWord> rootNodes = graph.getRoots();
        if (rootNodes.isEmpty()) {
            // Shouldn't happen, but return something!
            return("No Tree Found");
        }

        StringBuilder sb = new StringBuilder();
        Set<IndexedWord> used = Generics.newHashSet();
        for (IndexedWord root : rootNodes) {
            sb.append("0->").append(root).append(" (root)\n");
            recToString(graph, root, sb, 1, used);
        }
        Set<IndexedWord> nodes = Generics.newHashSet(graph.vertexSet());
        nodes.removeAll(used);
        while (!nodes.isEmpty()) {
            IndexedWord node = nodes.iterator().next();
            sb.append(node);
            recToString(graph, node, sb, 1, used);
            nodes.removeAll(used);
        }
        //sb.append(")");
        return sb.toString();
    }

    // helper for toString()
    private static void recToString(SemanticGraph graph, IndexedWord curr, StringBuilder sb, int offset, Set<IndexedWord> used) {
        used.add(curr);
        List<SemanticGraphEdge> edges = graph.outgoingEdgeList(curr);
        Collections.sort(edges);
        for (SemanticGraphEdge edge : edges) {
            IndexedWord target = edge.getTarget();
            sb.append(space(2*offset)).append(offset + "->").append(target).append(" (").append(edge.getRelation()).append(")\n");
            if (!used.contains(target)) { // recurse
                recToString(graph, target, sb, offset + 1, used);
            }
            //sb.append(space(2*offset)).append(")\n");
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
