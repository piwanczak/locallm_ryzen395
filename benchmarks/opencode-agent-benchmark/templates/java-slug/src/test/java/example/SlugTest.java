package example;

public final class SlugTest {
    public static void main(String[] args) {
        expect("hello-world", Slug.fromTitle(" Hello, World! "));
        expect("api-v2-release", Slug.fromTitle("API v2: release"));
        expect("edge-case", Slug.fromTitle("---Edge---Case---"));
    }

    private static void expect(String expected, String actual) {
        if (!expected.equals(actual)) {
            throw new AssertionError("expected " + expected + " but got " + actual);
        }
    }
}
