package com.shelfscanai.repository;

import com.shelfscanai.entity.UserBook;
import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

public interface UserBookRepository extends JpaRepository<UserBook, Long> {
    List<UserBook> findByUserKeyOrderByUpdatedAtDesc(String userKey);
    Optional<UserBook> findByUserKeyAndBook_Id(String userKey, Long bookId);
    void deleteByUserKeyAndBook_Id(String userKey, Long bookId);
}
