#pragma once
#import "EditorialTheme.h"

// Commands: bold, italic, underline, body, heading1, heading2, bullet, numbered, quote.
// Paragraph commands expand to complete selected paragraphs. The result selection
// follows inserted/removed list markers; adapters own undo and session flushing.
@interface NeonFormattingResult : NSObject
@property(nonatomic, copy) NSAttributedString* text;
@property(nonatomic) NSRange selection;
@property(nonatomic, copy) NSDictionary* typingAttributes;
@end
NeonFormattingResult* NeonFormatText(NSAttributedString* source, NSRange selection,
                                     NSString* command, NeonFont* baseFont);
NSDictionary* NeonFormatTyping(NSDictionary* attributes, NSString* command, NeonFont* baseFont);
BOOL NeonFormatActive(NSAttributedString* source, NSRange selection, NSString* command);
// Restyles the existing runs without discarding inline traits, links, lists,
// heading sizes or quote indentation. Must replace blanket font/style assignment.
void NeonRestyleText(NSMutableAttributedString* text, NeonFont* baseFont,
                     NSParagraphStyle* baseParagraph);
// Use on caret changes to retain inline traits while normalizing display-only
// blank separator spacing. Supply attributes at the insertion point.
NSDictionary* NeonRestyleTyping(NSDictionary* attributes, NeonFont* baseFont,
                                NSParagraphStyle* baseParagraph);

// Return handling for generated list items. Nil delegates to normal editor input.
// Cross-paragraph selections are deliberately left to the native text system.
NeonFormattingResult* NeonContinueList(NSAttributedString* source, NSRange selection,
                                       NSDictionary* typingAttributes, NeonFont* baseFont);
