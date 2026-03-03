package com.shelfscanai.repository;

import com.shelfscanai.entity.Book;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import java.util.List;
import java.util.Optional;

public interface BookRepository extends JpaRepository<Book, Long> {

    Optional<Book> findByTitleIgnoreCaseAndAuthorIgnoreCase(String title, String author);

    @Query("""
       select b from Book b
       where lower(b.title) like lower(concat('%', :q, '%'))
          or lower(coalesce(b.author,'')) like lower(concat('%', :q, '%'))
    """)
    List<Book> search(@Param("q") String q);

    Optional<Book> findByNormalizedTitleAndAuthorIgnoreCase(String normalizedTitle, String author);

    @Query("""
       select b from Book b
       where b.normalizedTitle = :nt
    """)
        List<Book> findByNormalizedTitle(@Param("nt") String normalizedTitle);

    @Query("""
       select b from Book b
       where b.description is not null
         and lower(coalesce(b.author,'')) = lower(:author)
         and (lower(b.title) like lower(concat('%', :q, '%'))
              or lower(:q) like lower(concat('%', lower(b.title), '%')))
    """)
        List<Book> findEnrichedCandidatesByAuthorAndTitleLike(@Param("author") String author,
                                                              @Param("q") String q);
}