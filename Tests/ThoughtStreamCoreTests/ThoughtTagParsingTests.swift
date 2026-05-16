import Testing
@testable import ThoughtStreamCore

struct ThoughtTagParsingTests {
    @Test
    func extractsInlineTagsAcrossMixedText() {
        let tags = ThoughtTagParser.extract(from: "干完现在的活 #工作，顺便提交 #thought-stream 和 #thought_stream")
        #expect(tags == ["工作", "thought-stream", "thought_stream"])
    }

    @Test
    func ignoresInvalidPhraseLikeTags() {
        let tags = ThoughtTagParser.extract(from: "#{just do it} #valid-tag #also_valid")
        #expect(tags == ["valid-tag", "also_valid"])
    }

    @Test
    func mergeDeduplicatesWhilePreservingOrder() {
        let merged = ThoughtTagParser.merge(["work", "idea"], ["idea", "review", "work"])
        #expect(merged == ["work", "idea", "review"])
    }

    @Test
    func invalidTagsRejectSpacesAndPhraseSyntax() {
        let invalid = ThoughtTagParser.invalidTags(in: ["code review", "#{idea}", "ok-tag"])
        #expect(invalid == ["code review", "#{idea}"])
    }
}
