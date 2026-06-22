package example;

public final class Slug {
    private Slug() {
    }

    public static String fromTitle(String title) {
        if (title == null) {
            throw new IllegalArgumentException("title is required");
        }

        String normalized = title.trim().toLowerCase();
        normalized = normalized.replaceAll("[^a-z0-9]+", "-");
        return normalized;
    }
}
