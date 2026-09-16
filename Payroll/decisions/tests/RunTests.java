///usr/bin/env jbang "$0" "$@" ; exit $?
//DEPS org.kie:kie-dmn-core:10.1.0
//DEPS org.slf4j:slf4j-simple:2.0.13
//JAVA 17+

// Runs candidate-offer-tests.xml against the decision models in the parent folder.
// No build and no project file: install jbang, then from Payroll/decisions run
//
//     jbang tests/RunTests.java
//
// Exit code 0 means every case matched. Pass -v to print the rationale each case
// produced, which is the part a reviewer actually reads.

import org.kie.dmn.api.core.*;
import org.kie.dmn.core.internal.utils.DMNRuntimeBuilder;
import org.kie.internal.io.ResourceFactory;
import org.kie.api.io.Resource;
import org.w3c.dom.*;
import javax.xml.parsers.DocumentBuilderFactory;
import java.io.File;
import java.math.BigDecimal;
import java.util.*;

public class RunTests {
    static final String NS = "https://aletyx.ai/dmn/payroll/candidate-offer";

    static List<Element> kids(Element e, String tag) {
        List<Element> out = new ArrayList<>();
        NodeList n = e.getChildNodes();
        for (int i = 0; i < n.getLength(); i++)
            if (n.item(i) instanceof Element c && c.getLocalName().equals(tag)) out.add(c);
        return out;
    }

    static Object value(Element v) {
        if ("true".equals(v.getAttributeNS("http://www.w3.org/2001/XMLSchema-instance", "nil")))
            return null;
        String type = v.getAttributeNS("http://www.w3.org/2001/XMLSchema-instance", "type");
        String text = v.getTextContent().trim();
        if (type.endsWith("boolean")) return Boolean.valueOf(text);
        if (type.endsWith("decimal")) return new BigDecimal(text);
        return text;
    }

    static Object component(Element c) {
        List<Element> lists = kids(c, "list");
        if (!lists.isEmpty()) {
            List<Object> out = new ArrayList<>();
            for (Element v : kids(lists.get(0), "value")) out.add(value(v));
            return out;
        }
        return value(kids(c, "value").get(0));
    }

    public static void main(String[] args) throws Exception {
        boolean verbose = Arrays.asList(args).contains("-v");
        File here = new File(RunTests.class.getProtectionDomain().getCodeSource()
                             .getLocation().toURI()).getParentFile();
        File testFile = new File("tests/candidate-offer-tests.xml").exists()
                ? new File("tests/candidate-offer-tests.xml")
                : new File(here, "candidate-offer-tests.xml");
        File models = testFile.getAbsoluteFile().getParentFile().getParentFile();

        List<Resource> res = new ArrayList<>();
        for (File f : models.listFiles((d, n) -> n.endsWith(".dmn")))
            res.add(ResourceFactory.newFileResource(f));
        if (res.isEmpty()) { System.out.println("no .dmn files beside " + models); System.exit(2); }

        DMNRuntime rt = DMNRuntimeBuilder.fromDefaults().buildConfiguration()
                .fromResources(res).getOrElseThrow(RuntimeException::new);
        boolean broken = false;
        for (DMNModel m : rt.getModels())
            for (DMNMessage msg : m.getMessages(DMNMessage.Severity.ERROR)) {
                System.out.println("MODEL ERROR [" + m.getName() + "] " + msg.getText());
                broken = true;
            }
        if (broken) System.exit(2);
        System.out.println(res.size() + " models compiled with no errors.\n");

        DMNModel model = rt.getModel(NS, "Candidate Offer");
        var dbf = DocumentBuilderFactory.newInstance();
        dbf.setNamespaceAware(true);
        Document doc = dbf.newDocumentBuilder().parse(testFile);

        int pass = 0, total = 0;
        for (Element tc : kids(doc.getDocumentElement(), "testCase")) {
            total++;
            String id = tc.getAttribute("id"), name = tc.getAttribute("name");
            Map<String, Object> candidate = new HashMap<>();
            for (Element c : kids(kids(tc, "inputNode").get(0), "component"))
                candidate.put(c.getAttribute("name"), component(c));

            Map<String, Object> expected = new LinkedHashMap<>();
            for (Element c : kids(kids(kids(tc, "resultNode").get(0), "expected").get(0), "component"))
                expected.put(c.getAttribute("name"), component(c));

            DMNContext ctx = rt.newContext();
            ctx.set("Candidate", candidate);
            DMNResult result = rt.evaluateAll(model, ctx);
            List<DMNMessage> errs = result.getMessages(DMNMessage.Severity.ERROR);
            if (!errs.isEmpty()) {
                System.out.printf("FAIL %s  %s%n", id, name);
                errs.stream().limit(3).forEach(e -> System.out.println("       " + e.getText()));
                continue;
            }
            Map<?, ?> offer = (Map<?, ?>) result.getDecisionResultByName("Candidate Offer").getResult();

            List<String> problems = new ArrayList<>();
            for (var e : expected.entrySet()) {
                Object want = e.getValue(), got = offer.get(e.getKey());
                boolean ok;
                if (want instanceof List<?> wl) {
                    List<?> gl = got == null ? List.of() : (List<?>) got;
                    ok = new HashSet<>(wl).equals(new HashSet<>(gl));
                } else if (want instanceof BigDecimal wb) {
                    ok = got instanceof BigDecimal gb && wb.compareTo(gb) == 0;
                } else {
                    ok = Objects.equals(want, got);
                }
                if (!ok) problems.add(String.format("%s expected %s but was %s",
                                                    e.getKey(), want, got));
            }
            if (problems.isEmpty()) {
                pass++;
                System.out.printf("PASS %s  %-58s %s%n", id, name, offer.get("offerAmount"));
            } else {
                System.out.printf("FAIL %s  %s%n", id, name);
                problems.forEach(p -> System.out.println("       " + p));
            }
            if (verbose) System.out.println("\n" + offer.get("rationale") + "\n");
        }
        System.out.printf("%n%d of %d cases passed.%n", pass, total);
        System.exit(pass == total ? 0 : 1);
    }
}
